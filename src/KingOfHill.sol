// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingOfHill is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasMinted; // Tracks if an address has an NFT
    mapping(address => uint256) private _points; // Tracks points for each NFT holder
    mapping(uint256 => address) private _tokenOwners; // Tracks token owners by tokenId
    address[] private _holders; // Tracks all NFT holders

    event Upgraded(address indexed holder, uint256 points, uint256 rank);

    constructor() ERC721("KingOfHill", "KOH") Ownable(msg.sender) {}

    function safeMint(address to) public onlyOwner {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[to] = true; // Mark the address as having an NFT

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);

        _tokenOwners[tokenId] = to; // Track the token owner
        _holders.push(to); // Add the holder to the list
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

        // Update token owner tracking
        _tokenOwners[tokenId] = to;

        // Update holders list
        for (uint256 i = 0; i < _holders.length; i++) {
            if (_holders[i] == from) {
                _holders[i] = to;
                break;
            }
        }

        super.transferFrom(from, to, tokenId);
    }

    // Calculate points based on wallet balance and assign rank
    function upgrade() public {
        require(balanceOf(msg.sender) > 0, "KingOfHill: Caller must own an NFT");

        // Calculate points based on wallet balance
        uint256 points = msg.sender.balance;
        _points[msg.sender] = points;

        // Calculate rank
        uint256 rank = 1;
        for (uint256 i = 0; i < _holders.length; i++) {
            if (_points[_holders[i]] > points) {
                rank++;
            }
        }

        emit Upgraded(msg.sender, points, rank);
    }

    // Get points for a specific holder
    function getPoints(address holder) public view returns (uint256) {
        return _points[holder];
    }

    // Get rank for a specific holder
    function getRank(address holder) public view returns (uint256) {
        uint256 points = _points[holder];
        uint256 rank = 1;
        for (uint256 i = 0; i < _holders.length; i++) {
            if (_points[_holders[i]] > points) {
                rank++;
            }
        }
        return rank;
    }

    // Get all holders
    function getHolders() public view returns (address[] memory) {
        return _holders;
    }
}