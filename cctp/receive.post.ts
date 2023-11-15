import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'
import { createWalletClient, http, publicActions } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { avalancheFuji } from 'viem/chains'

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const {messageHash, messageBytes, attestationResponse, payAmount, payCurrency, toAddress, receiveCurrency } = _.pick(body, ['messageHash', 'messageBytes', 'attestationResponse', 'payAmount', 'payCurrency', 'receiveCurrency', 'toAddress'])

  if (!messageHash || !messageBytes || !attestationResponse)
    return { error: 'Params is Invalid' }

  const attestationSignature = attestationResponse.attestation;

  const user = await serverSupabaseUser(event)
  const userId = user.id
  const adminClient = serverSupabaseServiceRole(event)
  const config = useRuntimeConfig(event)

  const walletClient = createWalletClient({
    account: privateKeyToAccount(config.ownerPrivateKey),
    chain: avalancheFuji,
    transport: http(),
  }).extend(publicActions)


  const contractInfo = getContractInfo('USDCMessageTransmitter', avalancheFuji.network)
  const params = {
      address: contractInfo.address,
      abi: contractInfo.abi,
      functionName: 'receiveMessage',
      args: [messageBytes, attestationSignature],
  }

  const {request} = await walletClient.simulateContract(params)
  const txHash = await walletClient.writeContract(request)
    
  const rz = await adminClient.from('circleAddFund').insert({
    userId,
    txHash,
    status: 'pending',
    metadata: {
      toAddress,
      payAmount,
      payCurrency,
      receiveCurrency,
    }
  }).select()

  return rz
})
