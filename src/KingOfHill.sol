// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KingOfHill is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasMinted; // Tracks if an address has an NFT
    mapping(address => uint256) private _points; // Tracks points for each NFT holder
    mapping(uint256 => address) private _tokenOwners; // Tracks token owners by tokenId
    address[] private _holders; // Tracks all NFT holders
    mapping(uint256 => string) private _rankImages; // Tracks image URLs for each rank
    address public mintWallet; // Address allowed to mint alongside the owner

    event Upgraded(address indexed source, address indexed target, uint256 points, uint256 rank);
    event RankImageSet(uint256 rank, string imageUrl);

    constructor(address initialOwner) ERC721("KingOfHill", "KOH") Ownable(initialOwner) {}

    modifier onlyOwnerOrMintWallet() {
        require(msg.sender == owner() || msg.sender == mintWallet, "Not authorized to mint");
        _;
    }

    function setMintWallet(address _mintWallet) external onlyOwner {
        mintWallet = _mintWallet;
    }

    // Allow the owner to set an image URL for a specific rank
    function setRankImage(uint256 rank, string memory imageUrl) public onlyOwner {
        _rankImages[rank] = imageUrl;
        emit RankImageSet(rank, imageUrl);
    }

    // Get the image URL for a specific rank
    function getRankImage(uint256 rank) public view returns (string memory) {
        return _rankImages[rank];
    }

    function safeMint(address to) public onlyOwnerOrMintWallet {
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

    function _exists(uint256 tokenId) internal view returns (bool) {
        address from = _ownerOf(tokenId);
        return from != address(0);
    }

    // Override tokenURI to dynamically generate metadata based on rank
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "KingOfHill: URI query for nonexistent token");

        address holder = ownerOf(tokenId);
        uint256 rank = getRank(holder);
        string memory imageUrl = _rankImages[rank];

        // Generate metadata JSON
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "KingOfHill #',
                tokenId.toString(),
                '", "description": "KingOfHill NFT with dynamic metadata based on rank.", ',
                '"image": "',
                imageUrl,
                '", "attributes": [{"trait_type": "Rank", "value": ',
                rank.toString(),
                "}]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", base64Encode(metadata)));
    }

    // Helper function to encode metadata as base64
    function base64Encode(string memory data) internal pure returns (string memory) {
        bytes memory encoded = bytes(data);
        if (encoded.length == 0) return "";

        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        uint256 encodedLen = 4 * ((encoded.length + 2) / 3);
        bytes memory result = new bytes(encodedLen);

        for (uint256 i = 0; i < encoded.length; i += 3) {
            uint256 j = i + 3 > encoded.length ? encoded.length : i + 3;
            uint256 a = uint256(uint8(encoded[i]));
            uint256 b = i + 1 < encoded.length ? uint256(uint8(encoded[i + 1])) : 0;
            uint256 c = i + 2 < encoded.length ? uint256(uint8(encoded[i + 2])) : 0;

            result[i / 3 * 4] = table[a >> 2];
            result[i / 3 * 4 + 1] = table[((a & 0x03) << 4) | (b >> 4)];
            result[i / 3 * 4 + 2] = table[((b & 0x0F) << 2) | (c >> 6)];
            result[i / 3 * 4 + 3] = table[c & 0x3F];
        }

        // Pad with '=' if necessary
        uint256 padding = encodedLen - (encoded.length + 2) / 3 * 4;
        for (uint256 i = 0; i < padding; i++) {
            result[encodedLen - 1 - i] = "=";
        }

        return string(result);
    }
}
