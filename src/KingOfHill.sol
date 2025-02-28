// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingOfHill is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasMinted; // Tracks if an address has an NFT

    constructor() ERC721("KingOfHill", "KOH") Ownable(msg.sender) {}

    function safeMint(address to) public onlyOwner {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[to] = true; // Mark the address as having an NFT

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);
    }

    // Override transferFrom to enforce the "one NFT per wallet" rule
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[from] = false; // Allow the sender to receive another NFT in the future
        _hasMinted[to] = true; // Mark the recipient as having an NFT

        super.transferFrom(from, to, tokenId);
    }
}