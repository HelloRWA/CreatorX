import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'
import { createWalletClient, parseEther, http, publicActions } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { avalancheFuji } from 'viem/chains'

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const {id} = _.pick(body, ['id'])

  if (!id)
    return { error: 'Params is Invalid' }

  const user = await serverSupabaseUser(event)
  const userId = user.id
  const adminClient = serverSupabaseServiceRole(event)
  const db = adminClient.from('circleAddFund')

  const {data, error} = await db.select()
    .eq('id', id)
    .eq('userId', userId)
    .single()

  if (!data) {
    return { error }
  }

  if (data.status !== 'pending') {
    return {
      error: 'record status is not pending'
    }
  }

  await db.update({status: 'startClaim'}).eq('id', id)

  const { toAddress, payAmount, receiveCurrency } = data.metadata
  let amount = payAmount + ''
  if (receiveCurrency === 'AVAX') {
    amount = (payAmount / 18).toFixed(2) + ''
  }
  amount = parseEther(amount)

  const config = useRuntimeConfig(event)

  const walletClient = createWalletClient({
    account: privateKeyToAccount(config.ownerPrivateKey),
    chain: avalancheFuji,
    transport: http(),
  }).extend(publicActions)


  const tx = await walletClient.waitForTransactionReceipt(
    { hash: data.txHash },
  )
  if (tx.status !== 'success') {
    return {
      error: `transaction not successed! ${data.txHash}`
    }
  }

  let claimTxHash = ''
  if (receiveCurrency === '$BSTEntropy') {
    const { address, abi } = getContractInfo('BSTEntropy')
    const params = {
      address,
      abi,
      functionName: 'mint',
      args: [toAddress, amount],
    }
    const { request } = await walletClient.simulateContract(params)
    claimTxHash = await walletClient.writeContract(request)
  }
  if (receiveCurrency === 'AVAX') {
    claimTxHash = await walletClient.sendTransaction({ 
      to: toAddress,
      value: amount
    })
  }

  const rz = await db.update({
    claimTxHash,
    status: 'claimed'
  }).eq('id', id).select()

  return rz
})
