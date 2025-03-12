// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/KingNad.sol";

contract KingNadTest is Test {
    KingNad kingNad;
    address owner = address(0x123);
    address mintWallet = address(0x456);
    address user1 = address(0x789);
    address user2 = address(0xABC);
    address erc20Token = address(0xDEF);
    address erc721Token = address(0x1234567890123456789012345678901234567890);

    function setUp() public {
        vm.prank(owner);
        kingNad = new KingNad(owner, mintWallet);
    }

    // Test the constructor initialization
    function test_Constructor() public {
        assertEq(kingNad.owner(), owner);
        assertEq(kingNad.mintWallet(), mintWallet);
        assertEq(kingNad.getNativeBalanceCoefficient(), 1);
    }

    // Test setting the mintWallet address
    function test_SetMintWallet() public {
        vm.prank(owner);
        kingNad.setMintWallet(user1);
        assertEq(kingNad.mintWallet(), user1);
    }

    // Test that only the owner can set the mintWallet
    function test_SetMintWallet_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        kingNad.setMintWallet(user1);
    }

    // Test pausing and unpausing minting
    function test_PauseUnpauseMinting() public {
        vm.prank(owner);
        kingNad.pauseMinting();
        assertTrue(kingNad.paused());

        vm.prank(owner);
        kingNad.unpauseMinting();
        assertFalse(kingNad.paused());
    }

    // Test that only the owner can pause/unpause minting
    function test_PauseUnpauseMinting_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        kingNad.pauseMinting();

        vm.prank(user1);
        vm.expectRevert();
        kingNad.unpauseMinting();
    }

    // Test setting rank images and metadata
    function test_SetRankImageAndMetadata() public {
        vm.prank(owner);
        kingNad.setRankImage(1, "image1.png");
        assertEq(kingNad.getRankImage(1), "image1.png");

        vm.prank(owner);
        kingNad.setRankMetadata(1, "metadata1.json");
        assertEq(kingNad.getRankMetadata(1), "metadata1.json");
    }

    // Test that only owner or mintWallet can set rank images and metadata
    function test_SetRankImageAndMetadata_RevertIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        kingNad.setRankImage(1, "image1.png");

        vm.prank(user1);
        vm.expectRevert("Not authorized");
        kingNad.setRankMetadata(1, "metadata1.json");
    }

    // Test minting an NFT
    function test_RequestMint() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();
        assertTrue(kingNad.hasNFT(user1));
        assertEq(kingNad.balanceOf(user1), 1);
        assertEq(kingNad.getCurrentMintFee(), 0.01001 ether); // 0.1% increase
    }

    // Test that minting reverts if the user already has an NFT
    function test_RequestMint_RevertIfAlreadyHasNFT() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();

        vm.prank(user1);
        vm.expectRevert("KingNad: Each address can hold only one NFT");
        kingNad.requestMint{value: 0.01 ether}();
    }

    // Test that minting reverts if the user has already requested a mint
    function test_RequestMint_RevertIfAlreadyRequestedMint() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();

        vm.prank(user1);
        kingNad.transferFrom(user1, user2, 0);

        vm.prank(user1);
        vm.expectRevert("KingNad: Each address can request a mint only once");
        kingNad.requestMint{value: 0.01 ether}();
    }

    // Test transferring an NFT
    function test_TransferFrom() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();

        vm.prank(user1);
        kingNad.transferFrom(user1, user2, 0);
        assertFalse(kingNad.hasNFT(user1));
        assertTrue(kingNad.hasNFT(user2));
        assertEq(kingNad.balanceOf(user2), 1);
    }

    // Test that transferring reverts if the recipient already has an NFT
    function test_TransferFrom_RevertIfRecipientHasNFT() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();

        uint256 mintFee = kingNad.getCurrentMintFee();

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        kingNad.requestMint{value: mintFee}();

        vm.prank(user1);
        vm.expectRevert("KingNad: Each address can hold only one NFT");
        kingNad.transferFrom(user1, user2, 0);
    }

    // Test upgrading points and rank
    function test_Upgrade() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        kingNad.requestMint{value: 0.01 ether}();

        // Simulate adding ERC20 and ERC721 tokens
        vm.prank(owner);
        kingNad.addERC20Token(erc20Token, 1);
        vm.prank(owner);
        kingNad.addERC721Token(erc721Token, 1);

        // Simulate balances
        vm.mockCall(erc20Token, abi.encodeWithSelector(IERC20.balanceOf.selector, user1), abi.encode(100));
        vm.mockCall(erc721Token, abi.encodeWithSelector(IERC721.balanceOf.selector, user1), abi.encode(1));

        vm.prank(user1);
        kingNad.upgrade();
        assertEq(kingNad.getPoints(user1), 990000000000000101); // 100 from ERC20, 1 from ERC721 + rest from native balance after minting fee
    }

    // Test adding and removing ERC20 tokens
    function test_AddRemoveERC20Token() public {
        vm.prank(owner);
        kingNad.addERC20Token(erc20Token, 1);
        assertEq(kingNad.getERC20Coefficient(erc20Token), 1);

        vm.prank(owner);
        kingNad.removeERC20Token(erc20Token);
        assertEq(kingNad.getERC20Tokens().length, 0);
    }

    // Test adding and removing ERC721 tokens
    function test_AddRemoveERC721Token() public {
        vm.prank(owner);
        kingNad.addERC721Token(erc721Token, 1);
        assertEq(kingNad.getERC721Coefficient(erc721Token), 1);

        vm.prank(owner);
        kingNad.removeERC721Token(erc721Token);
        assertEq(kingNad.getERC721Tokens().length, 0);
    }

    // Test setting the native balance coefficient
    function test_SetNativeBalanceCoefficient() public {
        vm.prank(owner);
        kingNad.setNativeBalanceCoefficient(2);
        assertEq(kingNad.getNativeBalanceCoefficient(), 2);
    }

    // Test that only the owner can set the native balance coefficient
    function test_SetNativeBalanceCoefficient_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        kingNad.setNativeBalanceCoefficient(2);
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
}
