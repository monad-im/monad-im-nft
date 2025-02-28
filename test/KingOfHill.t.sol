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

    // Test the upgrade function
    function testUpgrade() public {
        vm.prank(owner);
        nft.safeMint(user1);

        // Set user1's balance to 100 ETH
        vm.deal(user1, 100 ether);

        vm.prank(user1);
        nft.upgrade();

        // Check points and rank
        assertEq(nft.getPoints(user1), 100 ether);
        assertEq(nft.getRank(user1), 1);
    }

    // Test ranking with multiple holders
    function testRanking() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(owner);
        nft.safeMint(user2);

        // Set user1's balance to 100 ETH and user2's balance to 200 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 200 ether);

        vm.prank(user1);
        nft.upgrade();

        vm.prank(user2);
        nft.upgrade();

        // Check ranks
        assertEq(nft.getRank(user1), 2); // user1 has 100 ETH, user2 has 200 ETH
        assertEq(nft.getRank(user2), 1); // user2 has the highest balance
    }
}