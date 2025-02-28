// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingOfHill is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasMinted; // Tracks if an address has minted an NFT

    constructor() ERC721("KingOfHill", "KOH") {}

    function safeMint(address to) public onlyOwner {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[to] = true; // Mark the address as having minted an NFT

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);
    }
}