// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingOfHill is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasMinted; // Tracks if an address has an NFT

    // Pass the token name and symbol to the ERC721 constructor
    constructor() ERC721("KingOfHill", "KOH") Ownable() {}

    function safeMint(address to) public onlyOwner {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[to] = true; // Mark the address as having an NFT

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);
    }

    // Override _beforeTokenTransfer to enforce the "one NFT per wallet" rule
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        // Skip check for minting (from == address(0)) and burning (to == address(0))
        if (from != address(0)) {
            _hasMinted[from] = false; // Allow the sender to receive another NFT in the future
        }

        if (to != address(0)) {
            require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
            _hasMinted[to] = true; // Mark the recipient as having an NFT
        }
    }
}