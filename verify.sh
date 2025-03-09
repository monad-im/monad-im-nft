#!/bin/sh

CONTRACT_ADDRESS=$(jq -r '.transactions[0].contractAddress' broadcast/DeployKingNad.s.sol/10143/run-latest.json)

echo "Verifying contract at address $CONTRACT_ADDRESS"

forge verify-contract \
  --rpc-url https://testnet-rpc.monad.xyz \
  --verifier sourcify \
  --verifier-url 'https://sourcify-api-monad.blockvision.org' \
  $CONTRACT_ADDRESS \
  src/KingNad.sol:KingNad