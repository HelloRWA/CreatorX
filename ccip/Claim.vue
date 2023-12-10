
<script setup lang="ts">
import { optimismGoerli, avalancheFuji, mainnet, optimism, arbitrum, polygon, bsc, base, sepolia } from 'viem/chains'

const chainMap = {
  // mainnet, optimism, arbitrum, polygon, bsc, base
  sepolia,
  avalancheFuji,
}
const chainList = $ref(useMap(chainMap, item => item.name))
let sourceChainName = $ref(chainList[1])
const sourceChain = $computed(() => {
  const rz = useFilter(chainMap, item => item.name === sourceChainName)
  return rz[0]
})

let isAddFundLoading = $ref(false)
let addFundStatus = $ref('')

const { getBstEntropyBalance, getGasBalance, decodeAbiParameters, writeContract, ownerAddress, address, getBrowserWalletInstance, readContract, keccak256, toHex, getPublicClient } = $(rwaAuthStore())

let bstEntropyBalance = $ref(0)
let gasBalance = $ref(0)
let claimableAmount = $ref(0)
let isLoading = $ref(false)
let toAddress = $ref('')

const bstSwapAddress = getContractInfo('BSTSwap').address
let bstSwapBalance = $ref(0)
const queryBalance = async () => {
  isLoading = true

  try {
    console.log(`====> bstSwapAddress, address :`, bstSwapAddress, address)
    claimableAmount = await readContract('BSTBridge', 'tokenBalance', {}, bstSwapAddress, address)
    bstSwapBalance = await readContract('BSTSwap', 'balanceOf', {}, address)
  } catch (e) {
    console.log('====> e :', e,)
  }

  isLoading = false
}

watchEffect(async () => {
  await queryBalance()
})

const claimBST = async () => {
  if (isLoading) return
  isLoading = true
  const tx = await writeContract('BSTBridge', 'withdrawToken', {}, bstSwapAddress)

  const hash = useGet(tx, 'tx.transactionHash')
  console.log(`====> hash :`, hash)
  await queryBalance()
  isLoading = false
}

</script>
<template>
  <div class=" space-y-10 text-white">
    <h2>Target Chain on Fuji</h2>
    <BsLoading :isLoading="isAddFundLoading" :text="addFundStatus" space-y-6>
      <div>
        <label for="payAmount" class="flex  font-medium text-sm leading-6 justify-between items-center">
          <span>Claimable amount: {{ formatUnits(claimableAmount, 6) || '0' }} USDC</span>
          <BsLoadingIcon v-if="isLoading"></BsLoadingIcon>
          <BsBtnIndigo @click="queryBalance" :isLoading="isLoading" v-else>Refresh</BsBtnIndigo>
        </label>
      </div>
      <BsBtnIndigo @click="claimBST" w-full :isLoading="isAddFundLoading">Submit</BsBtnIndigo>
      <div mt-10>
        <label for="bstSwapBalance" class="font-medium text-sm text-white leading-6 block">BSTSwap Balance</label>
        <div flex-cc py-5 font-bold>
          {{ formatUnits(bstSwapBalance, 6) || '0' }} USDC
        </div>
      </div>
    </BsLoading>
  </div>
</template>
