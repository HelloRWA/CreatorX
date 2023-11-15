<script setup lang="ts">
import { goerli, avalancheFuji } from 'viem/chains'

interface Props {
  requiredBst: Number
  title?: string
}
let {
  title = "Select Label",
  requiredBst,
} = defineProps<Props>()
const emit = defineEmits(["update:modelValue"])

const { alertError, alertSuccess } = $(notificationStore())

let isShowDialog = $ref(false)
const { getBstEntropyBalance, getGasBalance, decodeAbiParameters, writeContract, ownerAddress, getBrowserWalletInstance, readContract, keccak256, toHex, getPublicClient } = $(rwaAuthStore())
let items = $ref([])
const wallet = $computed(() => {
  if (items.length === 0) return ''

  const rz = useFilter(items, item => item.blockchain === 'AVAX-FUJI')
  return rz[0]
})

let isLoading = $ref(true)
const queryWalletList = async walletSetType => {
  isLoading = true
  const { data, error } = $(await useGetRequest('/api/circle/walletSet', {
    walletSetType
  }))
  items = useGet(data, 'wallets')
  isLoading = false
}

let bstEntropyBalance = $ref(0)
let gasBalance = $ref(0)
let usdcBalance = $ref(0)

const queryBalance = async () => {
  isLoading = true
  bstEntropyBalance = await getBstEntropyBalance(wallet.address)
  gasBalance = await getGasBalance(wallet.address)

  const walletClient = await getBrowserWalletInstance(goerli)

  usdcBalance = await readContract('USDC', 'balanceOf', { walletClient }, walletClient.account.address)
  isLoading = false
}



watchEffect(async () => {
  if (!wallet.address) return

  await queryBalance()
})

onMounted(async () => {
  await queryWalletList('lotteryVault')
})

const payAmount = $ref(1)
const payCurrency = $ref('USDC')
const receiveCurrency = $ref('$BSTEntropy')
const receiveAmount = $computed(() => {
  if (receiveCurrency === 'AVAX') {
    return (payAmount / 18).toFixed(2)
  }
  return payAmount
})

let isAddFundLoading = $ref(false)
let addFundStatus = $ref('')
const addFund = async () => {
  if (isAddFundLoading) return
  isAddFundLoading = true

  const walletClient = await getBrowserWalletInstance(goerli)
  // 1. approve
  const payAmountInput = parseUnits(payAmount.toString(), 6)
  const spenderAddress = getContractInfo('USDCTokenMessenger', goerli.network).address
  const allowance = await readContract('USDC', 'allowance', { walletClient }, walletClient.account.address, spenderAddress)
  if (allowance < payAmountInput) {
    addFundStatus = 'Approve USDC spending'
    await writeContract('USDC', 'approve', { walletClient }, spenderAddress, payAmountInput)
  }

  // 2. burn
  addFundStatus = `deposit USDC for burn on ${goerli.name}`
  const mintRecipient = ownerAddress;
  const destinationAddressInBytes32 = addressToBytes32(mintRecipient)
  const AVAX_DESTINATION_DOMAIN = 1

  const burnUsdcContractAddress = getContractInfo('USDC', goerli.network).address
  const destinationCaller = addressToBytes32(ownerAddress)
  console.log('====> destinationCaller, mintRecipient :', destinationCaller, mintRecipient)
  const burnTx = await writeContract('USDCTokenMessenger', 'depositForBurnWithCaller', { walletClient }, payAmountInput, AVAX_DESTINATION_DOMAIN, destinationAddressInBytes32, burnUsdcContractAddress, destinationCaller)

  // 3. parse msg hash
  const hash = useGet(burnTx, 'tx.transactionHash')
  const transactionReceipt = await walletClient.getTransactionReceipt({ hash })
  const eventTopic = keccak256(toHex('MessageSent(bytes)'))
  const log = useFind(transactionReceipt.logs, l => {
    return l.topics[0] === eventTopic
  })
  const messageBytes = decodeAbiParameters([{
    type: 'bytes',
    name: 'message'
  }], log.data)[0]
  const messageHash = keccak256(messageBytes)
  // 4. check circle status
  addFundStatus = `checking attestations`
  let attestationResponse = { status: 'pending' };
  while (attestationResponse.status != 'complete') {
    const response = await fetch(`https://iris-api-sandbox.circle.com/attestations/${messageHash}`);
    attestationResponse = await response.json()
    await new Promise(r => setTimeout(r, 2000));
  }

  const fujiPublicClient = getPublicClient(avalancheFuji)
  // 5. call receiveMessage from server side
  addFundStatus = `wait for server to call receiveMessage on ${avalancheFuji.name}`
  const { data: _receiveData, error: receiveError } = $(await usePost('/api/circle/receive', {
    messageHash,
    messageBytes,
    toAddress: wallet.address,
    attestationResponse,
    payAmount, // TODO: should parse from server side, do not trust client input
    payCurrency,
    receiveCurrency,
  }))
  if (receiveError) {
    alertError(receiveError)
    return
  }
  const receiveData = _receiveData.data[0]
  const receiveHash = useGet(receiveData, 'txHash')
  const tx = await fujiPublicClient.waitForTransactionReceipt(
    { hash: receiveHash },
  )
  if (tx.status !== 'success') {
    alertError(tx.status)
    return
  }

  // 6. claim the order goods
  addFundStatus = `Claim your goods on ${avalancheFuji.network}`
  const { data: claimData, error: claimError } = $(await usePost('/api/circle/claim', {
    id: receiveData.id,
  }))
  if (claimError) {
    alertError(claimError)
    return
  }

  alertSuccess('Add Fund Successed!', async () => {
    await queryBalance()
    isShowDialog = false
  })
}

const walletBrowserLink = $computed(() => {
  const url = useGet(avalancheFuji, 'blockExplorers.default.url')
  return `${url}/address/${wallet.address}`
})

const lackOfBst = $computed(() => parseEther(requiredBst + '') - bstEntropyBalance)

const lackOfGasToken = $computed(() => {
  if (gasBalance < 0.13) return true
  return false
})
</script>

<template>
  <div space-y-1 pt-5>
    <div flex-bc space-x-2>
      <div flex-cc>
        {{ title }}
        <a :href="walletBrowserLink" class="flex ml-2 items-center hover:underline" target="_blank" v-if="!isLoading">
          <span>{{ shortAddress(wallet.address) }}</span>
          <span i-mi-external-link w-5 h-5 ml-1></span>
        </a>
      </div>
      <div text-gray-2 min-w-20 flex-cc>
        <BsLoadingIcon v-if="isLoading"></BsLoadingIcon>
        <div v-else flex-cc space-x-2>
          <div>
            {{ formatUnits(bstEntropyBalance) }} $BST
          </div>
          <div>
            {{ formatUnits(gasBalance) }} AVAX
          </div>
        </div>
      </div>
    </div>
    <div flex-ec text-gray-2 text-red space-x-2 v-if="!isLoading && lackOfBst > 0">
      <div>
        Still need fund {{ formatUnits(lackOfBst) }} $BST
      </div>
      <BsBtnIndigo class="h-8 px-2" @click="isShowDialog = true">Buy More</BsBtnIndigo>
    </div>
    <div class="flex-ec space-x-2 text-red text-gray-2 " v-if="!isLoading && lackOfGasToken">
      <div>
        Still need fund 0.1 AVAX
      </div>
      <BsBtnIndigo class="h-8 px-2" @click="isShowDialog = true">Buy More</BsBtnIndigo>
    </div>
    <BsDialogDefault :show="isShowDialog" :noPadding="true" @close="isShowDialog = false">
      <div min-w-lg bg-slate-8 py-15>
        <div class="pb-10 sm:mx-auto sm:max-w-sm sm:w-full">
          <h2 class="font-bold text-center text-white tracking-tight text-2xl leading-9">Add Fund Via Circle Service</h2>
        </div>
        <div class=" space-y-6 text-white sm:mx-auto sm:max-w-sm  sm:w-full">
          <BsLoading :isLoading="isAddFundLoading" :text="addFundStatus" space-y-3>
            <div>
              <label for="payAmount" class="flex  font-medium text-sm leading-6 justify-between items-center">
                <span>You pay (On Goerli)</span>
                <BsLoadingIcon v-if="isLoading"></BsLoadingIcon>
                <div v-else>
                  {{ formatUnits(usdcBalance, 6) }} USDC
                </div>
              </label>
              <div class="rounded-md shadow-sm mt-2 relative ">
                <input @keypress="keypressIsNumber($event)" type="text" v-model="payAmount" name="payAmount" id="payAmount" class="rounded-md bg-white/5 border-0 ring-inset text-white w-full py-1.5 pr-20 pl-2 ring-1 ring-gray-300 block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:(ring-inset ring-2 ring-indigo-600 placeholder:text-transparent) " placeholder="100" />
                <div class="flex inset-y-0 right-1 absolute items-center">
                  <label for="payCurrency" class="sr-only">Pay by</label>
                  <select id="payCurrency" name="payCurrency" v-model="payCurrency" class="bg-transparent rounded-md h-full border-0 text-right py-0 pr-2 pl-2 text-gray-200 sm:text-sm focus:ring-inset focus:ring-2 focus:ring-indigo-600">
                    <option>USDC</option>
                    <option>USD</option>
                  </select>
                </div>
              </div>
            </div>
            <fieldset v-show="payCurrency === 'USD'">
              <legend class="font-medium text-sm leading-6 block">Card Details</legend>
              <div class="-space-y-px rounded-md shadow-sm mt-2 text-white">
                <div>
                  <label for="card-number" class="sr-only">Card number</label>
                  <input type="text" name="card-number" id="card-number" class="rounded-none rounded-t-md bg-white/5 border-0 ring-inset w-full py-1.5 px-2 ring-1 ring-gray-300 relative block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:ring-inset focus:ring-2 focus:ring-indigo-600 focus:z-10" placeholder="Card number" />
                </div>
                <div class="-space-x-px flex">
                  <div class="flex-1 min-w-0 w-1/2">
                    <label for="card-expiration-date" class="sr-only">Expiration date</label>
                    <input type="text" name="card-expiration-date" id="card-expiration-date" class="rounded-none rounded-bl-md bg-white/5 border-0 ring-inset w-full py-1.5 px-2 ring-1 ring-gray-300 relative block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:ring-inset focus:ring-2 focus:ring-indigo-600 focus:z-10" placeholder="MM / YY" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <label for="card-cvc" class="sr-only">CVC</label>
                    <input type="text" name="card-cvc" id="card-cvc" class="rounded-none rounded-br-md bg-white/5 border-0 ring-inset w-full py-1.5 px-2 ring-1 ring-gray-300 relative block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:ring-inset focus:ring-2 focus:ring-indigo-600 focus:z-10" placeholder="CVC" />
                  </div>
                </div>
              </div>
            </fieldset>
            <div>
              <label for="receiveAmount" class="font-medium text-sm text-white leading-6 block">You receive (On Fuji)</label>
              <div class="rounded-md shadow-sm mt-2 relative ">
                <input type="text" v-model="receiveAmount" name="receiveAmount" id="receiveAmount" class="rounded-md bg-white/5 border-0 ring-inset text-white w-full py-1.5 pr-20 pl-2 ring-1 ring-gray-300 block placeholder:text-gray-400 sm:text-sm sm:leading-6 focus:(ring-inset ring-2 ring-indigo-600 placeholder:text-transparent) disabled:(cursor-not-allowed text-gray-4) " placeholder="" disabled />
                <div class="flex inset-y-0 right-1 absolute items-center">
                  <label for="receiveCurrency" class="sr-only">receiveCurrency</label>
                  <select id="receiveCurrency" name="receiveCurrency" v-model="receiveCurrency" class="bg-transparent rounded-md h-full border-0 text-right py-0 pr-2 pl-2 text-gray-200 sm:text-sm focus:ring-inset focus:ring-2 focus:ring-indigo-600">
                    <option>$BSTEntropy</option>
                    <option>AVAX</option>
                  </select>
                </div>
              </div>
            </div>
          </BsLoading>
          <BsBtnIndigo @click="addFund" w-full :isLoading="isAddFundLoading">Submit</BsBtnIndigo>
        </div>
      </div>
    </BsDialogDefault>
  </div>
</template>
