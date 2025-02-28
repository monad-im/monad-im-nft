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

    event Upgraded(address indexed source, address indexed target, uint256 points, uint256 rank);

    constructor() ERC721("KingOfHill", "KOH") Ownable(msg.sender) {}

    function safeMint(address to) public onlyOwner {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[to] = true; // Mark the address as having an NFT

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);

        _tokenOwners[tokenId] = to; // Track the token owner
        _holders.push(to); // Add the holder to the list

        // Calculate points based on wallet balance and assign to the caller
        _upgrade(to, to);
    }

    // Override transferFrom to enforce the "one NFT per wallet" rule and transfer points
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(!_hasMinted[to], "KingOfHill: Each address can hold only one NFT");
        _hasMinted[from] = false; // Allow the sender to receive another NFT in the future
        _hasMinted[to] = true; // Mark the recipient as having an NFT

        // Transfer points from the previous owner to the new owner
        _upgrade(from, to);
        _points[from] = 0; // Reset points for the previous owner

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

        // Calculate points based on wallet balance and assign to the caller
        _upgrade(msg.sender, msg.sender);
    }

    // Internal function to assign points from source to target
    function _upgrade(address source, address target) internal {
        uint256 points = _calculatePoints(source);
        _points[target] = points;

        // Emit an event with the updated points and rank
        emit Upgraded(source, target, points, getRank(target));
    }

    // Internal function to calculate points (can be extended later)
    function _calculatePoints(address source) internal view returns (uint256) {
        // For now, calculate points based on wallet balance
        return source.balance;
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
