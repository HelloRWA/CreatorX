import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'

const allowList = ['lotteryVault']

export default defineEventHandler(async (event) => {
  const { walletSetType } = getQuery(event)
    if (!allowList.includes(walletSetType)) {
    throw new Error(`walletSetType: ${walletSetType} is not in allow list!`)
    }
  
  const user = await serverSupabaseUser(event)
  const userId = user.id

  const adminClient = serverSupabaseServiceRole(event)

  // upsert  walletList table
  const circleWalletSetDB = adminClient.from('circleWalletSet')
  let walletSet = await circleWalletSetDB.select('*')
    .eq('userId', userId)
    .eq('walletSetType', walletSetType)
    .single()
  if (!walletSet.data) {
    walletSet = await circleWalletSetDB.insert({userId, walletSetType}).select()
  }
  const data = walletSet.data
  if (!data.walletSetId) {
    const name = `${user?.user_metadata.name}'s ${walletSetType} wallet set`
    const rz = await createCircleWalletRequest({
      name,
    }, { path: '/v1/w3s/developer/walletSets', event })
    const walletSet = _.get(rz, 'data.walletSet')
    const walletSetId = walletSet.id
    const walletSetCustodyType = walletSet.custodyType
    await circleWalletSetDB.update({
      walletSetId,
      walletSetCustodyType,
    }).eq('id', data.id)

    data.walletSetId = walletSetId
  }

  if (!data.wallets) {
    const rz = await createCircleWalletRequest({
      walletSetId: data.walletSetId,
      blockchains: [
        // 'ETH',
        // 'AVAX',
        // 'MATIC',
        'ETH-GOERLI',
        'AVAX-FUJI',
        'MATIC-MUMBAI',
      ],
      count: 1,
    }, { path: '/v1/w3s/developer/wallets', event })
    const wallets = _.get(rz, 'data.wallets')
    await circleWalletSetDB.update({
      wallets,
    }).eq('id', data.id)

    data.wallets = wallets
  }

  return data
})