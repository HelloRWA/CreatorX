# circle-programmable-wallets-cctp

## What it does

We build a blockchain base of X.com, all the new tweet require user to pay gas and ERC20 token to post.
User can login via X.com account and our system use the MPC wallet tech to create a new wallet for the user under the hood. So user do not need to import any private key on our platform but still have a wallet to interact with blockchain.

## What we do with Programmable Wallet and CCTP?

We use them in our *Random Lottery* module. 
User can create a new Lottery pool to attach to a new Tweet that other users can pay ERC20 token to buy the lottery and then get lucky then.
We use programmable wallet api to create a dev controlled programmable wallet to work as the vault of the lottery.
Also while the user lake of $BST and AVAX token, we use the *CCTP* to help user to use their *USDC on Georli* to buy *$BST and AVAX* on Fuji testnet.

* Create a new dev controled programmable wallet and attach to current login user
* While user try to post a new Tweet with *Random Lottery* attached
  * it require the user to fund enough $BST and also enough AVAX gas token in the programmable wallet
  * user can fund with their *USDC on Goerli* into *Fuji chain* via the CCTP tech

## Links

* [Demo Video]()
* [Relative Source code about Programmable Wallet]()
* [Relative Source code about CCTP]()
* We still heavy build our product of RWA-Wallet.com, plan to launch it before 2023/12/01
