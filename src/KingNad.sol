// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KingNad is ERC721, Ownable, Pausable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasNFT; // Tracks if an address has an NFT
    mapping(address => uint256) private _points; // Tracks points for each NFT holder
    mapping(uint256 => address) private _tokenOwners; // Tracks token owners by tokenId
    address[] private _holders; // Tracks all NFT holders
    mapping(uint256 => string) private _rankImages; // Tracks image URLs for each rank
    uint256 private _mintFee = 0.01 ether; // Initial mint fee
    uint256 private constant FEE_INCREASE_PERCENTAGE = 10; // 0.1% increase (10 basis points)
    mapping(address => bool) private _hasRequestedMint; // Tracks if a wallet has requested a mint
    address public mintWallet; // Address allowed to mint and set rank images

    event Upgraded(address indexed source, address indexed target, uint256 points, uint256 rank);
    event RankImageSet(uint256 rank, string imageUrl);
    event MintCompleted(address indexed recipient, uint256 tokenId, uint256 fee);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event MintingPaused(bool paused);

    constructor(address initialOwner, address initialMintWallet) ERC721("KingNad", "KNAD") Ownable(initialOwner) {
        require(initialMintWallet != address(0), "Invalid mintWallet address");
        mintWallet = initialMintWallet;
    }

    // Modifier to allow only the owner or mintWallet to call a function
    modifier onlyOwnerOrMintWallet() {
        require(msg.sender == owner() || msg.sender == mintWallet, "Not authorized");
        _;
    }

    // Function to set the mintWallet address (only owner)
    function setMintWallet(address _mintWallet) external onlyOwner {
        require(_mintWallet != address(0), "Invalid mintWallet address");
        mintWallet = _mintWallet;
    }

    // Function to withdraw all funds from the contract (only owner)
    function withdrawAllFunds() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        // Transfer the balance to the owner
        (bool success, ) = owner().call{value: contractBalance}("");
        require(success, "Transfer failed");

        // Emit an event to log the withdrawal
        emit FundsWithdrawn(owner(), contractBalance);
    }

    // Function to pause minting (only owner)
    function pauseMinting() external onlyOwner {
        _pause();
        emit MintingPaused(true);
    }

    // Function to unpause minting (only owner)
    function unpauseMinting() external onlyOwner {
        _unpause();
        emit MintingPaused(false);
    }

    // Allow the owner or mintWallet to set an image URL for a specific rank
    function setRankImage(uint256 rank, string memory imageUrl) public onlyOwnerOrMintWallet {
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

    // Allow users to mint NFTs directly by paying the mint fee
    function requestMint() public payable whenNotPaused {
        require(!_hasRequestedMint[msg.sender], "KingNad: Each address can request a mint only once");
        require(!_hasNFT[msg.sender], "KingNad: Each address can hold only one NFT");
        require(msg.value >= _mintFee, "KingNad: Insufficient mint fee");

        // Mark the address as having requested a mint (permanently)
        _hasRequestedMint[msg.sender] = true;

        // Mark the address as having an NFT
        _hasNFT[msg.sender] = true;

        // Mint the NFT
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(msg.sender, tokenId);

        // Track the token owner
        _tokenOwners[tokenId] = msg.sender;

        // Add the holder to the list
        _holders.push(msg.sender);

        // Transfer the mint fee to the owner
        uint256 fee = msg.value;
        payable(owner()).transfer(fee);

        // Increase the mint fee by 0.1% for the next request
        _mintFee += (_mintFee * FEE_INCREASE_PERCENTAGE) / 10000;

        // Calculate points based on wallet balance and assign to the caller
        _upgrade(msg.sender, msg.sender);

        emit MintCompleted(msg.sender, tokenId, fee);
    }

    // Override transferFrom to enforce the "one NFT per wallet" rule and transfer points
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(!_hasNFT[to], "KingNad: Each address can hold only one NFT");
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
        require(balanceOf(msg.sender) > 0, "KingNad: Caller must own an NFT");

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

    // Check if a wallet has an NFT
    function hasNFT(address wallet) public view returns (bool) {
        return _hasNFT[wallet];
    }

    // Check if a wallet has requested a mint
    function hasRequestedMint(address wallet) public view returns (bool) {
        return _hasRequestedMint[wallet];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        address from = _ownerOf(tokenId);
        return from != address(0);
    }

    // Override tokenURI to dynamically generate metadata based on rank
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "KingNad: URI query for nonexistent token");

        address holder = ownerOf(tokenId);
        uint256 rank = getRank(holder);
        string memory imageUrl = _rankImages[rank];

        // Generate metadata JSON
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "KingNad #',
                tokenId.toString(),
                '", "description": "KingNad NFT with dynamic metadata based on rank.", ',
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