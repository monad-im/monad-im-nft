#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check if necessary variables are set
if [[ -z "$PRIVATE_KEY" || -z "$RPC_URL" || -z "$SALT" ]]; then
    echo "❌ Error: PRIVATE_KEY, RPC_URL, or SALT is not set in .env"
    exit 1
fi

echo "🚀 Deploying KingNad contract using CREATE2 for a deterministic address..."

# Deploy using Foundry with CREATE2
DEPLOY_OUTPUT=$(forge script script/DeployKingNad.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast)
# DEPLOY_OUTPUT=$(forge create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --create2 --salt "$SALT" src/KingNad.sol:KingNad)

# Check if deployment was successful
if [[ $? -eq 0 ]]; then
    # Extract contract address from output
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    
    if [[ -n "$CONTRACT_ADDRESS" ]]; then
        echo "✅ Successfully deployed at deterministic address: $CONTRACT_ADDRESS"
        
        # Save contract address to a file
        echo "$CONTRACT_ADDRESS" > contract_address.txt
        echo "📜 Contract address saved to contract_address.txt"
    else
        echo "⚠️ Deployment succeeded but could not extract contract address!"
    fi

    forge inspect KingNad abi > KingNad.abi.json    
else
    echo "❌ Deployment failed!"
    exit 1
fi
