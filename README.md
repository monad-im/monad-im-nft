# KingNad NFT Smart Contract

This repository contains the smart contract for the KingNad NFT. 
KingNad is a unique NFT collection designed to take a new step in the NFT infrastructure by leveraging the potential capabilities of the Monad Chain.

Key features of KingNad:
- Unlimited number of NFTs (but the issuance price of each subsequent NFT is higher than the previous one)
- At any given time, one wallet can hold only one NFT
- The NFT is not just a symbol, but also shows the activity of the owner - the level and image can change depending on the state of the wallet and the state of the wallets of other owners
- When transferring an NFT from one owner to another, the NFT retains its properties but changes its ownership. However, the new owner can update the level and image of the NFT if desired
- The NFT can be used as a key to access various services in the future
- High-level NFTs can be used to participate in voting on future changes in KingNad

## Description

The KingNad NFT smart contract is written in Solidity and is designed to be deployed on the Ethereum blockchain. It follows the ERC-721 standard, which is the standard for non-fungible tokens (NFTs).

## How to Use with Foundry

Foundry is a blazing fast, portable, and modular toolkit for Ethereum application development written in Rust. Below are the steps to use the KingNad NFT smart contract with Foundry:

### Prerequisites

- Ensure you have Foundry installed. If not, you can install it by following the instructions [here](https://github.com/gakonst/foundry).

### Steps

1. **Clone the Repository**

  ```sh
  git clone https://github.com/monad-im/monad-im-nft.git
  cd monad-im-nft
  ```

2. **Install Dependencies**

  ```sh
  forge install
  ```

3. **Compile the Smart Contract**

  ```sh
  forge build
  ```

4. **Run Tests**

  ```sh
  forge test
  ```

5. **Deploy the Smart Contract**

  Use the `deploy.sh` script to deploy the smart contract to the Ethereum blockchain. The script will deploy the smart contract to the local blockchain by default. :

  ```sh
  ./deploy.sh
  ```

### Additional Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

Feel free to contribute to this project by opening issues or submitting pull requests.

## License

This project is licensed under the MIT License.