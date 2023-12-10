<script setup lang="ts">
const title = $ref('BST Bridge')
useHead({
  title,
})
definePageMeta({
  layout: 'airdrop',
  description: `World's first RWA Wallet: The ability to Tokenize real-world assets, Unleash the boundary of Web3 and Bring all human into metaverse.`
})

const tabs = $computed(() => {
  return [
    { name: 'Bridge', href: '#', current: currentTab === 'Bridge' },
    { name: 'Buy', href: '#', current: currentTab === 'Buy' },
  ]
})

const currentTab = $ref('Bridge')
</script>
<template>
  <div mx-auto flex flex-col w-full min-h-full items-center>
    <!-- <BstSwapStatus my-10 /> -->
    <div class="mx-auto my-20 text-center max-w-2xl">
      <h2 class="font-bold text-white tracking-tight text-4xl sm:text-6xl">BST Bridge</h2>
      <p class="mt-6 text-lg text-gray-300 leading-8">Cross Chain Bridge your USDC(Sepolia) into $BSTSwap(Fuji) via CCIP.</p>
    </div>
    <div>
      <div class="border-b border-gray-200 px-2 hidden">
        <nav class="flex -mb-px space-x-8" aria-label="Tabs">
          <button v-for="tab in tabs" :key="tab.name" @click="currentTab = tab.name" :class="[tab.current ? 'border-indigo-500 text-indigo-600' : 'border-transparent text-gray-500 hover:border-gray-200 hover:text-gray-700', 'flex whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium']" :aria-current="tab.current ? 'page' : undefined">
            {{ tab.name }}
          </button>
        </nav>
      </div>
      <div flex flex-col space-y-10>
        <BstSwapCCIP bg-gray-900 shadow sm:rounded-lg text-gray-1 sm:mx-auto sm:min-w-lg p-10 />
        <BstSwapClaim bg-gray-900 shadow sm:rounded-lg text-gray-1 sm:mx-auto sm:min-w-lg p-10 />
        <!-- <BstSwapBuy v-if="currentTab === 'Buy'" /> -->
      </div>
    </div>
  </div>
</template>
