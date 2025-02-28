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

    // Test that safeTransferFrom works and enforces the "one NFT per wallet" rule
    function testSafeTransferFrom() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(owner);
        nft.safeMint(user2);

        vm.prank(user1);
        vm.expectRevert("KingOfHill: Each address can hold only one NFT");
        nft.safeTransferFrom(user1, user2, 0);
    }

    // Test that safeTransferFrom with data works and enforces the "one NFT per wallet" rule
    function testSafeTransferFromWithData() public {
        vm.prank(owner);
        nft.safeMint(user1);

        vm.prank(owner);
        nft.safeMint(user2);

        vm.prank(user1);
        vm.expectRevert("KingOfHill: Each address can hold only one NFT");
        nft.safeTransferFrom(user1, user2, 0, "");
    }
}