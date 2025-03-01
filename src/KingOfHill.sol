// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KingOfHill is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasNFT; // Tracks if an address has an NFT
    mapping(address => uint256) private _points; // Tracks points for each NFT holder
    mapping(uint256 => address) private _tokenOwners; // Tracks token owners by tokenId
    address[] private _holders; // Tracks all NFT holders
    mapping(uint256 => string) private _rankImages; // Tracks image URLs for each rank
    address public mintWallet; // Address allowed to mint alongside the owner
    mapping(address => uint256) private _mintFees; // Tracks mint fees paid by each wallet
    mapping(address => bool) private _hasRequestedMint; // Tracks if a wallet has requested a mint
    uint256 private _mintFee = 0.01 ether; // Initial mint fee
    uint256 private constant FEE_INCREASE_PERCENTAGE = 10; // 0.1% increase (10 basis points)

    event Upgraded(address indexed source, address indexed target, uint256 points, uint256 rank);
    event RankImageSet(uint256 rank, string imageUrl);
    event MintRequested(address indexed requester, uint256 tokenId, uint256 fee);
    event MintCompleted(address indexed recipient, uint256 tokenId, uint256 fee);
    event MintRefunded(address indexed requester, uint256 fee);

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

    // Get the current mint fee
    function getCurrentMintFee() public view returns (uint256) {
        return _mintFee;
    }

    // Allow external wallets to request an NFT mint with a fee
    function requestMint() public payable {
        require(!_hasNFT[msg.sender], "KingOfHill: Each address can hold only one NFT");
        require(!_hasRequestedMint[msg.sender], "KingOfHill: Each address can request a mint only once");
        require(msg.value >= _mintFee, "KingOfHill: Insufficient mint fee");

        // Mark the address as having requested a mint (permanently)
        _hasRequestedMint[msg.sender] = true;

        // Track the mint fee paid by the requester
        _mintFees[msg.sender] = msg.value;

        // Increase the mint fee by 0.1% for the next request
        _mintFee += (_mintFee * FEE_INCREASE_PERCENTAGE) / 10000;

        emit MintRequested(msg.sender, _tokenIdCounter, msg.value);
    }

    // Owner-only mint function for wallets that have requested a mint
    function safeMint(address to) public onlyOwnerOrMintWallet {
        require(_mintFees[to] > 0, "KingOfHill: Only wallets that requested a mint can be minted to");
        require(!_hasNFT[to], "KingOfHill: Each address can hold only one NFT");

        // Mark the address as having an NFT
        _hasNFT[to] = true;

        // Mint the NFT
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);

        // Track the token owner
        _tokenOwners[tokenId] = to;

        // Add the holder to the list
        _holders.push(to);

        // Transfer the mint fee to the owner
        uint256 fee = _mintFees[to];
        payable(owner()).transfer(fee);

        // Reset the mint fee for the requester
        _mintFees[to] = 0;

        // Calculate points based on wallet balance and assign to the caller
        _upgrade(to, to);

        emit MintCompleted(to, tokenId, fee);
    }

    // Refund the mint fee if the mint cannot be completed
    function refundMint(address requester) public onlyOwner {
        require(_mintFees[requester] > 0, "KingOfHill: No mint request found for this address");
        require(!_hasNFT[requester], "KingOfHill: NFT already minted for this address");

        // Refund the mint fee
        uint256 fee = _mintFees[requester];
        payable(requester).transfer(fee);

        // Reset the mint fee and request status for the requester
        _mintFees[requester] = 0;
        _hasRequestedMint[requester] = false;

        // Rollback the mint fee increase
        _mintFee = (_mintFee * 10000) / (10000 + FEE_INCREASE_PERCENTAGE);

        emit MintRefunded(requester, fee);
    }

    // Override transferFrom to enforce the "one NFT per wallet" rule and transfer points
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(!_hasNFT[to], "KingOfHill: Each address can hold only one NFT");
        _hasNFT[from] = false; // Allow the sender to receive another NFT in the future
        _hasNFT[to] = true; // Mark the recipient as having an NFT

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

    // Get the mint fee paid by a specific wallet
    function getMintFee(address wallet) public view returns (uint256) {
        return _mintFees[wallet];
    }

    // Check if a wallet has requested a mint
    function hasRequestedMint(address wallet) public view returns (bool) {
        return _hasRequestedMint[wallet];
    }

    // Check if a wallet has an NFT
    function hasNFT(address wallet) public view returns (bool) {
        return _hasNFT[wallet];
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
