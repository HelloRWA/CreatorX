
<script setup lang="ts">
import { optimismGoerli, avalancheFuji, mainnet, optimism, arbitrum, polygon, bsc, base, sepolia } from 'viem/chains'

const chainMap = {
  // mainnet, optimism, arbitrum, polygon, bsc, base
  sepolia
}
const chainList = $ref(useMap(chainMap, item => item.name))
let sourceChainName = $ref(chainList[0])
const sourceChain = $computed(() => {
  const rz = useFilter(chainMap, item => item.name === sourceChainName)
  return rz[0]
})

let isAddFundLoading = $ref(false)
let addFundStatus = $ref('')

const { getBstEntropyBalance, getGasBalance, decodeAbiParameters, writeContract, ownerAddress, getBrowserWalletInstance, readContract, keccak256, toHex, getPublicClient } = $(rwaAuthStore())

let bstEntropyBalance = $ref(0)
let gasBalance = $ref(0)
let usdcBalance = $ref(0)
let isLoading = $ref(false)
let toAddress = $ref('')

const queryBalance = async () => {
  isLoading = true
  // bstEntropyBalance = await getBstEntropyBalance(toAddress)
  // gasBalance = await getGasBalance(toAddress)
  console.log(`====> sourceChain :`, sourceChain)
  const walletClient = await getBrowserWalletInstance(sourceChain)

  try {
    usdcBalance = await readContract('USDC', 'balanceOf', { walletClient }, walletClient.account.address)
  } catch (e) {
    console.log('====> e :', e, walletClient.account.address)
  }

  isLoading = false
}

watchEffect(async () => {
  await queryBalance()
})
const { alertSuccess } = $(notificationStore())

const payCurrency = $ref('USDC')
const payAmount = $ref('2')
const targetAddress = $ref('')
const receiveCurrency = $ref('$BSTSwap')
const receiveAmount = $computed(() => payAmount)
// const receiveAmount = $ref('')

const ccipConfigFuji = {
  router: '0x554472a2720e5e7d5d3c817529aba05eed5f82d8',
  link: '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846',
  chainSelector: '14767482510784806043'
}

const token = '0x76ca8e630415be9615396724f51ff1702b86ed63'
const receiver = '0xf7d4a584a56465a586b100f8c0e4067d8843e09b'
const amount = $computed(() => parseUnits(payAmount.toString(), 6))
const addFund = async () => {
  if (isAddFundLoading) return
  isAddFundLoading = true
  const walletClient = await getBrowserWalletInstance(sourceChain)
  const sendTokenTx = await writeContract('BSTBridge', 'sendToken', { walletClient },
    ccipConfigFuji.chainSelector,
    receiver,
    targetAddress,
    token,
    amount
  )

  const hash = useGet(sendTokenTx, 'tx.transactionHash')
  const transactionReceipt = await walletClient.getTransactionReceipt({ hash })
  console.log(`====> transactionReceipt :`, transactionReceipt)

  isAddFundLoading = false
  const link = `https://ccip.chain.link/tx/${hash}`
  alertSuccess(`Bridge Successed! Check out on CCIP: ${link}`)
}

const targetChain = $ref('Fuji')
</script>
<template>
  <div class=" space-y-10 text-white">
    <h2>Bridge From Sepolia</h2>
    <BsLoading :isLoading="isAddFundLoading" :text="addFundStatus" space-y-6>
      <div>
        <label for="sourceChainName" class="flex  font-medium text-sm leading-6 justify-between items-center">
          <span>Source chain</span>
        </label>
        <BsFormSelect v-model="sourceChainName" :list="chainList" w-full mt-2 />
      </div>
      <div>
        <label for="payAmount" class="flex  font-medium text-sm leading-6 justify-between items-center">
          <span>Pay amount</span>
          <BsLoadingIcon v-if="isLoading"></BsLoadingIcon>
          <div v-else>
            {{ formatUnits(usdcBalance, 6) || '0' }} USDC
          </div>
        </label>
        <div class="rounded-md shadow-sm mt-2 relative ">
          <input @keypress="keypressIsNumber($event)" type="text" v-model="payAmount" name="payAmount" id="payAmount" class="rounded-md bg-white/5 border-0 ring-inset text-white w-full py-1.5 pr-20 pl-2 ring-1 ring-gray-300 block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:(ring-inset ring-2 ring-indigo-600 placeholder:text-transparent) " placeholder="100" />
          <div class="flex inset-y-0 right-1 absolute items-center">
            <label for="payCurrency" class="sr-only">Pay by</label>
            <select id="payCurrency" name="payCurrency" v-model="payCurrency" class="bg-transparent rounded-md h-full border-0 text-right py-0 pr-2 pl-2 text-gray-200 sm:text-sm focus:ring-inset focus:ring-2 focus:ring-indigo-600">
              <option>USDC</option>
            </select>
          </div>
        </div>
      </div>
      <div>
        <label for="receiveAmount" class="font-medium text-sm text-white leading-6 block">Target address</label>
        <div class="rounded-md shadow-sm mt-2 relative ">
          <input type="text" v-model="targetAddress" name="targetAddress" id="targetAddress" class="rounded-md bg-white/5 border-0 ring-inset text-white w-full py-1.5 pr-20 pl-2 ring-1 ring-gray-300 block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:(ring-inset ring-2 ring-indigo-600 placeholder:text-transparent) disabled:(cursor-not-allowed text-gray-4) " placeholder="Please input your target wallet address" />
        </div>
      </div>
      <div>
        <label for="receiveAmount" class="font-medium text-sm text-white leading-6 block">Receive (on Avax Fuji testnet)</label>
        <div class="rounded-md shadow-sm mt-2 relative ">
          <input type="text" v-model="receiveAmount" name="receiveAmount" id="receiveAmount" class="rounded-md bg-white/5 border-0 ring-inset text-white w-full py-1.5 pr-20 pl-2 ring-1 ring-gray-300 block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:(ring-inset ring-2 ring-indigo-600 placeholder:text-transparent) disabled:(cursor-not-allowed text-gray-4) " placeholder="" disabled />
          <div class="flex inset-y-0 right-1 absolute items-center">
            <label for="receiveCurrency" class="sr-only">receiveCurrency</label>
            <select id="receiveCurrency" name="receiveCurrency" v-model="receiveCurrency" class="bg-transparent rounded-md h-full border-0 text-right py-0 pr-2 pl-2 text-gray-200 sm:text-sm focus:ring-inset focus:ring-2 focus:ring-indigo-600">
              <option>$BSTSwap</option>
            </select>
          </div>
        </div>
      </div>
    </BsLoading>
    <BsBtnIndigo @click="addFund" w-full :isLoading="isAddFundLoading">Submit</BsBtnIndigo>
  </div>
</template>
