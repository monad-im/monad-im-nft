// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/KingNad.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract KingNadTest is Test {
    KingNad public kingNad;
    address public owner = address(0x123);
    address public mintWallet = address(0x012);
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC721 public erc721Token1;

    function setUp() public {
        // Deploy the KingNad contract with the owner and mintWallet addresses
        vm.prank(owner);
        kingNad = new KingNad(owner, mintWallet);

        // Deploy mock ERC20 and ERC721 tokens
        token1 = new MockERC20("Token1", "TKN1");
        token2 = new MockERC20("Token2", "TKN2");
        erc721Token1 = new MockERC721("ERC721Token1", "NFT1");

        // Add ERC20 and ERC721 tokens to the KingNad contract
        vm.prank(owner);
        kingNad.addERC20Token(address(token1), 100); // 100x multiplier for token1
        vm.prank(owner);
        kingNad.addERC20Token(address(token2), 50); // 50x multiplier for token2
        vm.prank(owner);
        kingNad.addERC721Token(address(erc721Token1), 500); // 500x multiplier for each ERC721 token1

        // Set native balance coefficient
        vm.prank(owner);
        kingNad.setNativeBalanceCoefficient(10); // 10x multiplier for native balance
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

        vm.prank(user1);
        kingNad.transferFrom(user1, user2, 0);

        // Attempt to mint again with the same wallet
        vm.prank(user1);
        vm.expectRevert("KingNad: Each address can request a mint only once");
        kingNad.requestMint{value: initialMintFee}();
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

    // Test points calculation with native balance and ERC20 tokens
    function testPointsCalculationERC20() public {
        // User1 requests a mint
        vm.deal(user1, 1 ether); // Give user1 1 ETH
        token1.mint(user1, 100); // Give user1 100 token1
        token2.mint(user1, 200); // Give user1 200 token2

        // User1 requests a mint
        uint256 mintFee = kingNad.getCurrentMintFee();
        vm.prank(user1);
        kingNad.requestMint{value: mintFee}();

        // Calculate expected points
        uint256 nativeBalanceAfterMint = 1 ether - mintFee;
        uint256 expectedPoints = (nativeBalanceAfterMint * 10) + (100 * 100) + (200 * 50);
        assertEq(kingNad.getPoints(user1), expectedPoints);
    }

    // Test points calculation with native balance, ERC20 tokens, and ERC721 tokens
    function testPointsCalculationERC721() public {
        vm.deal(user1, 1 ether); // Give user1 1 ETH
        token1.mint(user1, 100); // Give user1 100 token1
        erc721Token1.mint(user1, 1); // Give user1 1 ERC721 token1

        // User1 requests a mint
        uint256 mintFee = kingNad.getCurrentMintFee();
        vm.prank(user1);
        kingNad.requestMint{value: mintFee}();

        // Calculate expected points
        uint256 nativeBalanceAfterMint = 1 ether - mintFee;
        uint256 expectedPoints = (nativeBalanceAfterMint * 10) + (100 * 100) + (1 * 500);
        assertEq(kingNad.getPoints(user1), expectedPoints);
    }
}
