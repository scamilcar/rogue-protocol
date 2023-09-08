# Welcome to Rogue repository  
## Core contracts

### Manager.sol 
This contract is used to create and manage vaults. It can:
- create a booster
- remove a booster from the protocol
- add a new reward to a booster
- remove a token from a booster rewards in case it is stale
- update the duration of a reward for a booster
- update the compounder of a booster (the compounder can change the booster reward mode)
- update the protocol fee
- batch : distribute rewards, collect fees, claim rewards, compound rewards  

### Booster.sol  
This contract is a ERC4626 vault used to deposit Boosted Positions LP tokens from Maverick AMM.
The depositors are eligible to: 
- extra incentives tokens in Boosted Positions
- MAV (normal mode) and/or more LP tokens overtime (compound mode)
The authorized compounder of this contract can choose the MAV reward mode.  


### Locker.sol  
This contract is used to deposit MAV on Rogue.
- Depositors receive a ERC20 (rMAV) at a 1:1 ratio.
- Depositors cam withdraw their MAV until withdrawals are disabled.
- Once enabled, anybody can call the function `lock` to trigger the lock extension 
mechanism and receive rMAV as incentive.
- This contract respects the Layer Zero OFT standard  

### Staker.sol
This contract is used to stake rMAV and respects the ERC4626 standard.
Staker receives voting power over MAV emissions and can claim rewards.  
You don't need to unstake to transfer the shares to another address. 
Users can delegate their vote. 

## Periphery contracts
### Board.sol
This contract:
- should contain the vote logic for rMAV AND eROG
- should contain redistribution logic of differents protocol fees to differents parties
- is the owner of the LP tokens 
- is the owner of the veMAV

### Bounties.sol
This contract is used to distribute bounties to voters.
- anyone can create a bounty
- bounty creator chooses: the `pool`, the `rewardToken`, the `totalRewardAmount`, the `numberOfPeriods`,
the `maxRewardPerVote` and the `manager` of the bounty
- the manager of the bounty can upgrade it 
- Voters are eligible to claim rewards pro-rata to their voting power at the change of epoch, capped to the maximum price per reward.

### Broker.sol
This contract is used for Rogue liquidity mining.
- The entry point to minting this NFT is claiming MAV as a LP on Rogue.
- The owner of a NFT can buy ROG at a discount until the expiry of the option.
- When exercising, caller can either receive ROG token or convert them right away.
- The discount is either based on platform activity or set by the owner of this contract.

### Hub.sol
This contract inherits from `ERC4626BaseRouter from Fei Protocol.  
It serves as user facing contract : users interact with this contract to deposit into booster. It checks for slippage and contains UX improving utilities.

### ROG.sol
This is the ROG token contract.  
- Owner can update emissions parameters
- It respects the Layer Zero OFT standard  

## Tests

You will find all the contracts under `/contracts`.  
This repo uses [Foundry](https://github.com/foundry-rs/foundry) as test framework. Install it, then:  

Instantiate a mainnet fork with the following `foundry` command:  
```
$ anvil -f <MAINNET_RPC_URL>
```
To run test:
```
$ forge test  
```  
To generate a gas report:  
```
$ forge test --gas-report
```
To get the test coverage:
```
$ forge coverage
``` 

From Maverick ABDK audits:
- MAV are distributed monthly
- MAV should be distributed in lpReward, how more efficiently distribute them?
- veMAV fees is 50% of the protocol fees at the beginning
- vote with an `id` for `IReward` array with `uint[]`

TODO:
LiquidityRewarder.sol:  
-reset to original maverick reward duration to be sure reward period never exceeds 30 days.  
LockRewarder.sol:

Audit list: 
- C4
- ABDK : all, logic
- Dedaub : pool position
- hanfriese : tokenomics

