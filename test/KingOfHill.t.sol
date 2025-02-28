// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/KingOfHill.sol";

contract KingOfHillTest is Test {
    KingOfHill private nft;
    address private owner = address(0x123);
    address private user1 = address(0x456);
    address private user2 = address(0x789);

    function setUp() public {
        // Deploy the contract with the owner address
        vm.prank(owner);
        nft = new KingOfHill();
    }

    // Test minting an NFT
    function testMint() public {
        vm.prank(owner);
        nft.safeMint(user1);
        assertEq(nft.ownerOf(0), user1);
    }

    // Test that a user cannot mint more than one NFT
    function testCannotMintTwice() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(owner);
        vm.expectRevert("KingOfHill: Each address can hold only one NFT");
        nft.safeMint(user1);
    }

    // Test that an NFT cannot be transferred to a wallet that already has an NFT
    function testCannotTransferToWalletWithNFT() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(owner);
        nft.safeMint(user2);

        vm.prank(user1);
        vm.expectRevert("KingOfHill: Each address can hold only one NFT");
        nft.transferFrom(user1, user2, 0);
    }

    // Test that an NFT can be transferred to a wallet that does not have an NFT
    function testCanTransferToWalletWithoutNFT() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, 0);

        assertEq(nft.ownerOf(0), user2);
    }

    // Test that points are transferred from the previous owner to the new owner
    function testPointsTransferOnTransfer() public {
        vm.prank(owner);
        nft.safeMint(user1);

        // Set user1's balance to 100 ETH
        vm.deal(user1, 100 ether);

        // Call upgrade to assign points to user1
        vm.prank(user1);
        nft.upgrade();

        // Transfer the NFT from user1 to user2
        vm.prank(user1);
        nft.transferFrom(user1, user2, 0);

        // Check that user1's points are reset to 0
        assertEq(nft.getPoints(user1), 0);

        // Check that user2 now has user1's points
        assertEq(nft.getPoints(user2), 100 ether);
    }

    // Test that the upgrade function assigns points to the caller
    function testUpgradeFunction() public {
        vm.prank(owner);
        nft.safeMint(user1);

        // Set user1's balance to 100 ETH
        vm.deal(user1, 100 ether);

        // Call upgrade to assign points to user1
        vm.prank(user1);
        nft.upgrade();

        // Check that user1's points are updated
        assertEq(nft.getPoints(user1), 100 ether);
    }
}
