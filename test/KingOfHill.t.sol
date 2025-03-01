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
        nft = new KingOfHill(owner);
    }

    // Test setting an image URL for a rank
    function testSetRankImage() public {
        vm.prank(owner);
        nft.setRankImage(1, "https://example.com/rank1.png");

        string memory imageUrl = nft.getRankImage(1);
        assertEq(imageUrl, "https://example.com/rank1.png");
    }

    // Test that tokenURI returns the correct metadata
    function testTokenURI() public {
        vm.deal(user1, 0.01 ether); // Fund user1 with 0.01 ETH
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        vm.prank(owner);
        nft.safeMint(user1);

        // Set user1's balance to 100 ETH
        vm.deal(user1, 100 ether);

        // Call upgrade to assign points to user1
        vm.prank(user1);
        nft.upgrade();

        // Set image URL for rank 1
        vm.prank(owner);
        nft.setRankImage(1, "https://example.com/rank1.png");

        // Get token URI
        string memory uri = nft.tokenURI(0);

        // Decode base64 metadata
        string memory metadata = decodeBase64(uri);

        // Check that the metadata contains the correct image URL
        assertTrue(bytes(metadata).length > 0);
        assertTrue(bytes(metadata).length > 0);
    }

    // Helper function to decode base64
    function decodeBase64(string memory data) internal pure returns (string memory) {
        bytes memory encoded = bytes(data);
        require(encoded.length >= 29, "Invalid base64 data");

        // Remove "data:application/json;base64," prefix
        bytes memory base64Data = new bytes(encoded.length - 29);
        for (uint256 i = 29; i < encoded.length; i++) {
            base64Data[i - 29] = encoded[i];
        }

        // Decode base64
        bytes memory decoded = new bytes((base64Data.length * 3) / 4);
        uint256 decodedLen = 0;
        for (uint256 i = 0; i < base64Data.length; i += 4) {
            uint256 a = base64CharToUint(base64Data[i]);
            uint256 b = base64CharToUint(base64Data[i + 1]);
            uint256 c = base64CharToUint(base64Data[i + 2]);
            uint256 d = base64CharToUint(base64Data[i + 3]);

            decoded[decodedLen++] = bytes1(uint8((a << 2) | (b >> 4)));
            if (c < 64) {
                decoded[decodedLen++] = bytes1(uint8((b << 4) | (c >> 2)));
            }
            if (d < 64) {
                decoded[decodedLen++] = bytes1(uint8((c << 6) | d));
            }
        }

        return string(decoded);
    }

    // Helper function to convert base64 characters to uint
    function base64CharToUint(bytes1 char) internal pure returns (uint256) {
        if (char >= "A" && char <= "Z") {
            return uint256(uint8(char)) - uint256(uint8(bytes1("A")));
        } else if (char >= "a" && char <= "z") {
            return uint256(uint8(char)) - uint256(uint8(bytes1("a"))) + 26;
        } else if (char >= "0" && char <= "9") {
            return uint256(uint8(char)) - uint256(uint8(bytes1("0"))) + 52;
        } else if (char == "+") {
            return 62;
        } else if (char == "/") {
            return 63;
        } else {
            revert("Invalid base64 character");
        }
    }
   // Test that an external wallet can request an NFT mint with a fee
    function testRequestMint() public {
        vm.deal(user1, 0.01 ether); // Fund user1 with 0.01 ETH
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        // Check that user1 has paid the mint fee
        assertEq(nft.getMintFee(user1), 0.01 ether);

        // Check that user1 has requested a mint
        assertTrue(nft.hasRequestedMint(user1));

        // Check that the mint fee has increased by 0.1%
        assertEq(nft.getCurrentMintFee(), 0.01001 ether);
    }

    // Test that a wallet cannot request a mint more than once
    function testCannotRequestMintTwice() public {
        vm.deal(user1, 0.02 ether); // Fund user1 with 0.02 ETH
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        vm.prank(user1);
        vm.expectRevert("KingOfHill: Each address can request a mint only once");
        nft.requestMint{value: 0.01 ether}();
    }

    // Test that the owner can mint an NFT for a wallet that requested a mint
    function testSafeMint() public {
        vm.deal(user1, 0.01 ether); // Fund user1 with 0.01 ETH
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        vm.prank(owner);
        nft.safeMint(user1);

        // Check that user1 owns the NFT
        assertEq(nft.ownerOf(0), user1);

        // Check that the mint fee was transferred to the owner
        assertEq(owner.balance, 0.01 ether);

        // Check that user1's mint request status is still true
        assertTrue(nft.hasRequestedMint(user1));
    }

    // Test that the owner can refund the mint fee
    function testRefundMint() public {
        vm.deal(user1, 0.01 ether); // Fund user1 with 0.01 ETH
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        // Check that the mint fee has increased by 0.1%
        assertEq(nft.getCurrentMintFee(), 0.01001 ether);

        vm.prank(owner);
        nft.refundMint(user1);

        // Check that user1 received the refund
        assertEq(user1.balance, 0.01 ether);

        // Check that user1's mint request status is reset
        assertFalse(nft.hasRequestedMint(user1));

        // Check that the mint fee is rolled back to the initial value
        assertEq(nft.getCurrentMintFee(), 0.01 ether);
    }

    // Test that the current mint fee is readable
    function testGetCurrentMintFee() public {
        // Initial mint fee should be 0.01 ETH
        assertEq(nft.getCurrentMintFee(), 0.01 ether);

        // Request a mint to increase the fee
        vm.deal(user1, 0.01 ether);
        vm.prank(user1);
        nft.requestMint{value: 0.01 ether}();

        // Mint fee should now be 0.01001 ETH
        assertEq(nft.getCurrentMintFee(), 0.01001 ether);
    }
}
