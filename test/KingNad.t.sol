// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/KingNad.sol";

contract KingNadTest is Test {
    KingNad public kingNad;
    address public owner = address(0x123);
    address public mintWallet = address(0x012);
    address public user1 = address(0x456);
    address public user2 = address(0x789);

    function setUp() public {
        // Deploy the KingNad contract with the owner and mintWallet addresses
        vm.prank(owner);
        kingNad = new KingNad(owner, mintWallet);
    }

    // Test minting an NFT
    function testMintNFT() public {
        vm.deal(user1, 1 ether); // Give user1 some Ether
        uint256 initialMintFee = kingNad.getCurrentMintFee();

        // User1 requests a mint
        vm.prank(user1);
        kingNad.requestMint{value: initialMintFee}();

        // Verify that user1 now owns an NFT
        assertTrue(kingNad.hasNFT(user1));
        assertEq(kingNad.balanceOf(user1), 1);

        // Verify that the mint fee has increased
        uint256 newMintFee = kingNad.getCurrentMintFee();
        assertGt(newMintFee, initialMintFee);
    }

    // Test that a wallet can only mint once
    function testOneMintPerWallet() public {
        vm.deal(user1, 1 ether); // Give user1 some Ether
        uint256 initialMintFee = kingNad.getCurrentMintFee();

        // User1 requests a mint
        vm.prank(user1);
        kingNad.requestMint{value: initialMintFee}();

        // Attempt to mint again with the same wallet
        vm.prank(user1);
        vm.expectRevert("KingNad: Each address can request a mint only once");
        kingNad.requestMint{value: initialMintFee}();
    }

    // // Test withdrawing funds by the owner
    // function testWithdrawFunds() public {
    //     vm.deal(user1, 1 ether); // Give user1 some Ether
    //     uint256 initialMintFee = kingNad.getCurrentMintFee();

    //     // User1 requests a mint
    //     vm.prank(user1);
    //     kingNad.requestMint{value: initialMintFee}();

    //     // Owner withdraws funds
    //     uint256 contractBalanceBefore = address(kingNad).balance;
    //     vm.prank(owner);
    //     kingNad.withdrawAllFunds();

    //     // Verify that the contract balance is now 0
    //     assertEq(address(kingNad).balance, 0);

    //     // Verify that the owner received the funds
    //     assertEq(owner.balance, contractBalanceBefore);
    // }

    // Test pausing and unpausing minting
    function testPauseUnpauseMinting() public {
        vm.deal(user1, 1 ether); // Give user1 some Ether
        uint256 initialMintFee = kingNad.getCurrentMintFee();

        // Pause minting
        vm.prank(owner);
        kingNad.pauseMinting();

        // Attempt to mint while paused
        vm.prank(user1);
        vm.expectRevert();
        kingNad.requestMint{value: initialMintFee}();

        // Unpause minting
        vm.prank(owner);
        kingNad.unpauseMinting();

        // Mint should now succeed
        vm.prank(user1);
        kingNad.requestMint{value: initialMintFee}();
        assertTrue(kingNad.hasNFT(user1));
    }

    // Test setting rank images
    function testSetRankImage() public {
        string memory imageUrl = "https://example.com/rank1.png";
        uint256 rank = 1;

        // Owner sets a rank image
        vm.prank(owner);
        kingNad.setRankImage(rank, imageUrl);

        // Verify that the rank image was set
        assertEq(kingNad.getRankImage(rank), imageUrl);
    }

    // Test transferring NFTs and updating points
    function testTransferNFT() public {
        vm.deal(user1, 1 ether); // Give user1 some Ether
        uint256 initialMintFee = kingNad.getCurrentMintFee();

        // User1 requests a mint
        vm.prank(user1);
        kingNad.requestMint{value: initialMintFee}();

        // Transfer NFT from user1 to user2
        uint256 tokenId = 0;
        vm.prank(user1);
        kingNad.transferFrom(user1, user2, tokenId);

        // Verify that user2 now owns the NFT
        assertTrue(kingNad.hasNFT(user2));
        assertEq(kingNad.balanceOf(user2), 1);

        // Verify that user1 no longer owns the NFT
        assertFalse(kingNad.hasNFT(user1));
        assertEq(kingNad.balanceOf(user1), 0);
    }

    // Test setting rank image by owner
    function testSetRankImageByOwner() public {
        string memory imageUrl = "https://example.com/rank1.png";
        uint256 rank = 1;

        // Owner sets a rank image
        vm.prank(owner);
        kingNad.setRankImage(rank, imageUrl);

        // Verify that the rank image was set
        assertEq(kingNad.getRankImage(rank), imageUrl);
    }

    // Test setting rank image by mintWallet
    function testSetRankImageByMintWallet() public {
        string memory imageUrl = "https://example.com/rank1.png";
        uint256 rank = 1;

        // mintWallet sets a rank image
        vm.prank(mintWallet);
        kingNad.setRankImage(rank, imageUrl);

        // Verify that the rank image was set
        assertEq(kingNad.getRankImage(rank), imageUrl);
    }

    // Test setting rank image by unauthorized address
    function testSetRankImageByUnauthorized() public {
        string memory imageUrl = "https://example.com/rank1.png";
        uint256 rank = 1;

        // Unauthorized user attempts to set a rank image
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        kingNad.setRankImage(rank, imageUrl);
    }
}