# CreatorX

![product Logic](https://raw.githubusercontent.com/HelloRWA/CreatorX/main/main.png)

## What it does

We build a blockchain base of X.com, all the new tweets require user to pay gas and ERC20 tokens to post.
User can log in via an X.com account and our system use the MPC wallet tech to create a new wallet for the user under the hood. So users do not need to import any private key on our platform but still have a wallet to interact with blockchain.

![product screenshot](https://raw.githubusercontent.com/HelloRWA/CreatorX/main/screenshot-1.jpg)

## What do we do with the CCIP and VRF from ChainLink?

We build a `BST Bridge` via the CCIP that help our user to spend USDC from Sepolia and get `$BSTSwap` on Fuji.
And user can use the `$BSTSwap` token to playaround our social application on Fuji.

* [`BSTBridge.sol`](https://github.com/HelloRWA/CreatorX/blob/main/ccip/BSTBridge.sol) which we deploy on Sepolia as sender and Fuji as receiver
  * A demo CCIP call <https://ccip.chain.link/msg/0x43323c1905629337486f8e6de9774a1444e9167075b57ca783a972ba2923f91c>
  * The Sender on Sepolia we deploy: <https://sepolia.etherscan.io/address/0x54c17ec7226c9b51ff15c96b4662d668505555f9>
  * The Receiver on Fuji we deploy: <https://testnet.snowtrace.io/address/0x7a0d634ab5c038e7b038d1452c4a122ed498dae2>
* [`BST Bridge UI - Send Token`](https://github.com/HelloRWA/CreatorX/blob/main/ccip/CCIP.vue)
* [`BST Bridge UI - Claim Token`](https://github.com/HelloRWA/CreatorX/blob/main/ccip/Claim.vue)
* [`RandomLottery.sol`](https://github.com/HelloRWA/CreatorX/blob/main/vrf/RandomLottery.sol)

## What do we do with the Fuji Chain?

We deploy our social contract on the Fuji Chain: <https://testnet.snowtrace.io/address/0x1cb4b8060d15Afcc531Ec2d81f76bD29C586fEF0>

## What do we do with Programmable Wallet and CCTP?

We use them in our *Random Lottery* module.
Users can create a new Lottery pool to attach to a new Tweet that other users can pay ERC20 tokens to buy the lottery and then get lucky.
We use programmable wallet API to create a dev-controlled programmable wallet to work as the vault of the lottery.
Also while the user lake of $BST and AVAX token, we use the *CCTP* to help the user use their *USDC on Georli* to buy *$BST and AVAX* on Fuji testnet.

![circle integrated screenshot](https://raw.githubusercontent.com/HelloRWA/CreatorX/main/screenshot-2.jpg)

* Create a new dev controlled programmable wallet and attach it to current login user
  * [Frontend code](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/wallet.vue#L27-L34) && [screenshot](https://github.com/HelloRWA/CreatorX/blob/main/screenshot/programmable-wallet-for-lottery-vault.png)
  * Frontend make request to api server which call the code in [backend api code](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/walletSet.get.ts)
  * The backend code check if current login user already have the programmable wallet created first: [code](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/walletSet.get.ts#L17-L40)
    * If already created, just return to frondend
    * If not, call the func [createCircleWalletRequest](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/walletSet.get.ts#L43C22-L60) in [circle-sdk script](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/circle-sdk.ts)
* While the user try to post a new Tweet with *Random Lottery* attached
  * it requires the user to fund enough $BST and also enough AVAX gas token in the programmable wallet
  * user can fund with their *USDC on Goerli* into *Fuji chain* via the CCTP tech
  * [fund-AVAX-via-USD.png](https://github.com/HelloRWA/CreatorX/blob/main/screenshot/fund-AVAX-via-USD.png)
  * [fund-ERC20-via-USDC.png](https://github.com/HelloRWA/CreatorX/blob/main/screenshot/fund-ERC20-via-USDC.png)
  * [Frontend code which request user's metamask wallet to fund with USDC on Goerli](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/wallet.vue#L75-L161)
  * Backend code that delevery the $BST or AVAX gas token to the Programmable Wallet Vault
    * We use the *depositForBurnWithCaller* feature [code](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/programmable-wallet/wallet.vue#L98), so we need our server side to call the *USDCMessageTransmitter.receiveMessage* method [code](https://github.com/HelloRWA/circle-programmable-wallets-cctp/blob/main/cctp/receive.post.ts#L27-L36)
* We also manual use the *circle-mint in app-sanbox* that fund our wallet with 2000 USDC on Goerli
  * Which we will integrate the feature into our product that provide user to pay via credit card to buy USDC.

## Links

* [Demo Video](https://youtu.be/XfFiRW33q-8)
* [Relative Source code about Programmable Wallet](https://github.com/HelloRWA/CreatorX/blob/main/programmable-wallet)
  * [Programmable wallet we create(link to snowtrace)](https://testnet.snowtrace.io/address/0xe3a4ee3674b7952d5f4457a94d3a3ab163e7679f)
* [Relative Source code about CCTP](https://github.com/HelloRWA/CreatorX/blob/main/cctp)
* [Pitch Deck for RWA-Wallet.com](https://pitch.com/public/724fc677-e462-4ddc-bbb1-bb389d8ed886)
* [RWAProtocol contract address deploy on Fuji 0x1cb4b8060d15Afcc531Ec2d81f76bD29C586fEF0](https://testnet.snowtrace.io/address/0x1cb4b8060d15Afcc531Ec2d81f76bD29C586fEF0)
* [BSTEntropy contract address deploy on Fuji 0xB9e94A2Cb0Ef78deBc25D76e8f62E1C024c15A17](https://testnet.snowtrace.io/address/0xB9e94A2Cb0Ef78deBc25D76e8f62E1C024c15A17)

## What's next

* We still heavy build our product of RWA-Wallet.com, plan to launch it before 2024
* Deploy on mainnet of ETH
* Deploy on AVAX chain