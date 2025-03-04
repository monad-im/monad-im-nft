import "../src/KingNad.sol";

import "forge-std/Script.sol";

contract DeployKingNad is Script {
    address owner = 0x71F4ca206d0466097d6017225eb4A41a35C0d757;  // Change this to the owner's address
    address mintWallet = 0xFFB484E5024d25fc1Df3507562Ec99006EAf1D0f;  // Change this to the mintWallet's address

    function run() public {
        // Create the bytecode for the KingOfHill contract
        bytes memory bytecode = type(KingNad).creationCode;
        
        // Define the salt value (could be any unique value for different deployments)
        bytes32 salt = keccak256(abi.encodePacked(owner));

        // Calculate the contract's address using CREATE2
        address predictedAddress;
        assembly {
            predictedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        // Deploy the contract at the calculated address
        vm.startBroadcast();
        new KingNad{salt: salt}(owner, mintWallet); // Deploying the contract with the specified salt
        vm.stopBroadcast();

        console.log("Contract deployed at address:", predictedAddress);
    }
}