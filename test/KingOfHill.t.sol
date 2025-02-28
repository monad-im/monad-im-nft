// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/KingOfHill.sol";

contract KingOfHillTest is Test {
    KingOfHill private nft;
    address private owner = address(0x123);
    address private user = address(0x456);

    function setUp() public {
        nft = new KingOfHill();
    }

    function testMint() public {
        vm.prank(owner);
        nft.safeMint(user);
        assertEq(nft.ownerOf(0), user);
    }
}