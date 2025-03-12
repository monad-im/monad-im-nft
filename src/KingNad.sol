/**
 * @title KingNad
 * @dev An ERC721 NFT contract with ranking system based on wallet assets
 *
 * KingNad implements a unique NFT system where:
 * - Each wallet can mint or hold only one NFT
 * - NFT holders are ranked based on their wallet assets (native balance, ERC20, and * @dev An ERC721 NFT contract with unique ranking system based on wallet assets
 *
 * The KingNad NFT implements a specialized ranking system where each holder's rank
 * is determined by the value of assets in their wallet. Points are calculated based on:
 * - Native token balance (ETH/MATIC/etc.)
 * - ERC20 token balances (weighted by configurable coefficients)
 * - ERC721 token holdings (weighted by configurable coefficients)
 *
 * Key features:
 * - One NFT per wallet enforcement
 * - Dynamic mint fee that increases by 0.1% with each mint
 * - Ranking system based on wallet assets
 * - Metadata and images that change based on holder's rank
 * - Transfer restrictions to maintain one NFT per wallet rule
 *
 * The contract allows the owner and designated mintWallet to:
 * - Set rank-specific images and metadata
 * - Add/remove supported ERC20 and ERC721 tokens for points calculation
 * - Configure coefficients for different assets in points calculation
 * - Pause/unpause minting process
 *
 * For end users:
 * - Request to mint an NFT by paying the current fee
 * - Update their rank by calling the upgrade function
 * - Transfer NFTs subject to the one-per-wallet restriction
 *
 * Points and ranks are recalculated during transfers and can be manually updated.
 *
 * Note: This contract is for educational purposes only and not suitable for production.
 * Visit https://kingnad.xyz for more information.
 */

/**
 * Storage:
 * @notice _tokenIdCounter - Tracks the next token ID to mint
 * @notice _hasNFT - Mapping to track if an address has an NFT
 * @notice _points - Mapping to track points for each NFT holder
 * @notice _tokenOwners - Mapping to track token owners by tokenId
 * @notice _holders - Array to track all NFT holders
 * @notice _rankImages - Mapping to track image URLs for each rank
 * @notice _rankMetadata - Mapping to track metadata URLs for each rank
 * @notice _mintFee - The current mint fee (starts at 0.01 ETH, increases by 0.1% per mint)
 * @notice _hasRequestedMint - Mapping to track if a wallet has requested a mint
 * @notice mintWallet - Address allowed to mint and set rank images
 * @notice _erc20Tokens - List of ERC20 tokens to consider for points calculation
 * @notice _erc20Coefficients - Coefficients for ERC20 tokens in points calculation
 * @notice _erc721Tokens - List of ERC721 tokens to consider for points calculation
 * @notice _erc721Coefficients - Coefficients for ERC721 tokens in points calculation
 * @notice _nativeBalanceCoefficient - Coefficient for native balance in points calculation
 *
 * Events:
 * @notice Upgraded - Emitted when a holder's points and rank are updated
 * @notice RankImageSet - Emitted when an image URL is set for a rank
 * @notice RankMetadataSet - Emitted when a metadata URL is set for a rank
 * @notice MintCompleted - Emitted when an NFT is minted
 * @notice MintingPaused - Emitted when minting is paused or unpaused
 * @notice ERC20TokenAdded - Emitted when an ERC20 token is added to the points system
 * @notice ERC20TokenRemoved - Emitted when an ERC20 token is removed from the points system
 * @notice ERC721TokenAdded - Emitted when an ERC721 token is added to the points system
 * @notice ERC721TokenRemoved - Emitted when an ERC721 token is removed from the points system
 * @notice NativeBalanceCoefficientUpdated - Emitted when the native balance coefficient is updated
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * This code is create for the KingNads NFT project.
 * For educational purposes only!
 * Not suitable for production.
 * Explore more on https://kingnad.xyz
 */
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract KingNad is ERC721, Ownable, Pausable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(address => bool) private _hasNFT; // Tracks if an address has an NFT
    mapping(address => uint256) private _points; // Tracks points for each NFT holder
    mapping(uint256 => address) private _tokenOwners; // Tracks token owners by tokenId
    address[] private _holders; // Tracks all NFT holders
    mapping(uint256 => string) private _rankImages; // Tracks image URLs for each rank
    mapping(uint256 => string) private _rankMetadata; // Tracks metadata URLs for each rank
    uint256 private _mintFee = 0.01 ether; // Initial mint fee
    uint256 private constant FEE_INCREASE_PERCENTAGE = 10; // 0.1% increase (10 basis points)
    mapping(address => bool) private _hasRequestedMint; // Tracks if a wallet has requested a mint
    address public mintWallet; // Address allowed to mint and set rank images

    // ERC20 token list and coefficients
    address[] private _erc20Tokens; // List of ERC20 tokens to consider for points
    mapping(address => uint256) private _erc20Coefficients; // Coefficients for ERC20 tokens

    // ERC721 token list and coefficients
    address[] private _erc721Tokens; // List of ERC721 tokens to consider for points
    mapping(address => uint256) private _erc721Coefficients; // Coefficients for ERC721 tokens

    uint256 private _nativeBalanceCoefficient; // Coefficient for native balance

    event Upgraded(address indexed source, address indexed target, uint256 points, uint256 rank);
    event RankImageSet(uint256 rank, string imageUrl);
    event RankMetadataSet(uint256 rank, string metadataUrl);
    event MintCompleted(address indexed recipient, uint256 tokenId, uint256 fee);
    event MintingPaused(bool paused);
    event ERC20TokenAdded(address indexed token, uint256 coefficient);
    event ERC20TokenRemoved(address indexed token);
    event ERC721TokenAdded(address indexed token, uint256 coefficient);
    event ERC721TokenRemoved(address indexed token);
    event NativeBalanceCoefficientUpdated(uint256 coefficient);

    constructor(address initialOwner, address initialMintWallet) ERC721("KingNad", "KNAD") Ownable(initialOwner) {
        require(initialMintWallet != address(0), "Invalid mintWallet address");
        mintWallet = initialMintWallet;
        _nativeBalanceCoefficient = 1; // Default coefficient for native balance
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

    // Allow the owner or mintWallet to set a metadata URL for a specific rank
    function setRankMetadata(uint256 rank, string memory metadataUrl) public onlyOwnerOrMintWallet {
        _rankMetadata[rank] = metadataUrl;
        emit RankMetadataSet(rank, metadataUrl);
    }

    // Get the image URL for a specific rank
    function getRankImage(uint256 rank) public view returns (string memory) {
        return _rankImages[rank];
    }

    // Get the metadata URL for a specific rank
    function getRankMetadata(uint256 rank) public view returns (string memory) {
        return _rankMetadata[rank];
    }

    // Get the current mint fee
    function getCurrentMintFee() public view returns (uint256) {
        return _mintFee;
    }

    // Allow users to mint NFTs directly by paying the mint fee
    function requestMint() public payable whenNotPaused {
        require(!_hasNFT[msg.sender], "KingNad: Each address can hold only one NFT");
        require(!_hasRequestedMint[msg.sender], "KingNad: Each address can request a mint only once");
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

    // Internal function to calculate points
    function _calculatePoints(address source) internal view returns (uint256) {
        uint256 points = 0;

        // Add native balance contribution
        points += source.balance * _nativeBalanceCoefficient;

        // Add ERC20 token balances contribution
        for (uint256 i = 0; i < _erc20Tokens.length; i++) {
            address token = _erc20Tokens[i];
            uint256 balance = IERC20(token).balanceOf(source);
            uint256 coefficient = _erc20Coefficients[token];
            points += balance * coefficient;
        }

        // Add ERC721 token balances contribution
        for (uint256 i = 0; i < _erc721Tokens.length; i++) {
            address token = _erc721Tokens[i];
            uint256 balance = IERC721(token).balanceOf(source);
            uint256 coefficient = _erc721Coefficients[token];
            points += balance * coefficient;
        }

        return points;
    }

    // Get points for a specific holder
    function getPoints(address holder) public view returns (uint256) {
        return _points[holder];
    }

    // Get rank for a specific holder
    function getRank(address holder) public view returns (uint256) {
        // If the holder doesn't exist or has no points, return rank 0
        if (!_hasNFT[holder] || _points[holder] == 0) {
            return 0;
        }

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

    // Override tokenURI to return the metadata URL based on rank
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "KingNad: URI query for nonexistent token");

        address holder = ownerOf(tokenId);
        uint256 rank = getRank(holder);

        // If rank is 0, return a default metadata URL or revert
        if (rank == 0) {
            return "https://example.com/metadata/default.json";
        }

        string memory metadataUrl = _rankMetadata[rank];
        require(bytes(metadataUrl).length > 0, "KingNad: Metadata URL not set for this rank");

        return metadataUrl;
    }

    // Add an ERC20 token to the list (only owner)
    function addERC20Token(address token, uint256 coefficient) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(coefficient > 0, "Coefficient must be greater than 0");

        _erc20Tokens.push(token);
        _erc20Coefficients[token] = coefficient;

        emit ERC20TokenAdded(token, coefficient);
    }

    // Remove an ERC20 token from the list (only owner)
    function removeERC20Token(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");

        // Remove the token from the list
        for (uint256 i = 0; i < _erc20Tokens.length; i++) {
            if (_erc20Tokens[i] == token) {
                _erc20Tokens[i] = _erc20Tokens[_erc20Tokens.length - 1];
                _erc20Tokens.pop();
                break;
            }
        }

        // Remove the coefficient
        delete _erc20Coefficients[token];

        emit ERC20TokenRemoved(token);
    }

    // Add an ERC721 token to the list (only owner)
    function addERC721Token(address token, uint256 coefficient) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(coefficient > 0, "Coefficient must be greater than 0");

        _erc721Tokens.push(token);
        _erc721Coefficients[token] = coefficient;

        emit ERC721TokenAdded(token, coefficient);
    }

    // Remove an ERC721 token from the list (only owner)
    function removeERC721Token(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");

        // Remove the token from the list
        for (uint256 i = 0; i < _erc721Tokens.length; i++) {
            if (_erc721Tokens[i] == token) {
                _erc721Tokens[i] = _erc721Tokens[_erc721Tokens.length - 1];
                _erc721Tokens.pop();
                break;
            }
        }

        // Remove the coefficient
        delete _erc721Coefficients[token];

        emit ERC721TokenRemoved(token);
    }

    // Update the native balance coefficient (only owner)
    function setNativeBalanceCoefficient(uint256 coefficient) external onlyOwner {
        require(coefficient > 0, "Coefficient must be greater than 0");

        _nativeBalanceCoefficient = coefficient;

        emit NativeBalanceCoefficientUpdated(coefficient);
    }

    // Get the list of ERC20 tokens
    function getERC20Tokens() public view returns (address[] memory) {
        return _erc20Tokens;
    }

    // Get the coefficient for a specific ERC20 token
    function getERC20Coefficient(address token) public view returns (uint256) {
        return _erc20Coefficients[token];
    }

    // Get the list of ERC721 tokens
    function getERC721Tokens() public view returns (address[] memory) {
        return _erc721Tokens;
    }

    // Get the coefficient for a specific ERC721 token
    function getERC721Coefficient(address token) public view returns (uint256) {
        return _erc721Coefficients[token];
    }

    // Get the native balance coefficient
    function getNativeBalanceCoefficient() public view returns (uint256) {
        return _nativeBalanceCoefficient;
    }
}
