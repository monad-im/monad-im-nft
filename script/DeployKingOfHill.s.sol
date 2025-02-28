import "../src/KingOfHill.sol";

import "forge-std/Script.sol";

contract DeployKingOfHill is Script {
    address owner = 0x71F4ca206d0466097d6017225eb4A41a35C0d757;  // Change this to the owner's address

    function run() public {
        // Create the bytecode for the KingOfHill contract
        bytes memory bytecode = type(KingOfHill).creationCode;
        
        // Define the salt value (could be any unique value for different deployments)
        bytes32 salt = keccak256(abi.encodePacked(owner));

        // Calculate the contract's address using CREATE2
        address predictedAddress;
        assembly {
            predictedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        // Deploy the contract at the calculated address
        vm.startBroadcast();
        new KingOfHill{salt: salt}(owner); // Deploying the contract with the specified salt
        vm.stopBroadcast();

        console.log("Contract deployed at address:", predictedAddress);
    }
}