//TODO:
// payment/royalty addresses
// add/remove from presale public or only owner?

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

/**
 *
 * Ok Let's Go Monkeys NFT contract
 *
 */
contract OKLGMonkeys is
  Ownable,
  ERC721Burnable,
  ERC721Enumerable,
  ERC721Pausable
{
  using SafeMath for uint256;
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  // Base token uri
  string private baseTokenURI; // baseTokenURI can point to IPFS folder like https://ipfs.io/ipfs/{cid}/

  // Payment address
  address private paymentAddress;

  // Royalties address
  address private royaltyAddress;

  // Royalties basis points (percentage using 2 decimals - 10000 = 100, 0 = 0)
  uint256 private royaltyBasisPoints = 1000; // 10%

  // Token info
  string public constant TOKEN_NAME = 'OKLG Monkeys';
  string public constant TOKEN_SYMBOL = 'mOKLG';
  uint256 public constant TOTAL_TOKENS = 10000;

  uint256 public mintCost = 0.542069 ether;
  uint256 public maxWalletAmount = 100;

  // Pre sale/Public sale active
  bool public preSaleActive;
  bool public publicSaleActive;

  // Presale whitelist
  mapping(address => bool) public presaleWhitelist;

  //-- Events --//
  event RoyaltyBasisPoints(uint256 indexed _royaltyBasisPoints);

  //-- Modifiers --//

  // Public sale active modifier
  modifier whenPreSaleActive() {
    require(preSaleActive, 'Pre sale is not active');
    _;
  }

  // Public sale active modifier
  modifier whenPublicSaleActive() {
    require(publicSaleActive, 'Public sale is not active');
    _;
  }

  // Owner or public sale active modifier
  modifier whenOwnerOrSaleActive() {
    require(
      owner() == _msgSender() || preSaleActive || publicSaleActive,
      'Sale is not active'
    );
    _;
  }

  // -- Constructor --//
  constructor(string memory _baseTokenURI) ERC721(TOKEN_NAME, TOKEN_SYMBOL) {
    baseTokenURI = _baseTokenURI;

    paymentAddress = _msgSender();
    royaltyAddress = _msgSender();
  }

  // -- External Functions -- //

  // Start pre sale
  function startPreSale() external onlyOwner {
    preSaleActive = true;
    publicSaleActive = false;
  }

  // End pre sale
  function endPreSale() external onlyOwner {
    preSaleActive = false;
    publicSaleActive = false;
  }

  // Start public sale
  function startPublicSale() external onlyOwner {
    preSaleActive = false;
    publicSaleActive = true;
  }

  // End public sale
  function endPublicSale() external onlyOwner {
    preSaleActive = false;
    publicSaleActive = false;
  }

  // Support royalty info - See {EIP-2981}: https://eips.ethereum.org/EIPS/eip-2981
  function royaltyInfo(uint256, uint256 _salePrice)
    external
    view
    returns (address receiver, uint256 royaltyAmount)
  {
    return (royaltyAddress, (_salePrice.mul(royaltyBasisPoints)).div(10000));
  }

  // Adds multiple addresses to whitelist
  function addToPresaleWhitelist(address[] memory _addresses)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < _addresses.length; i++) {
      address _address = _addresses[i];
      presaleWhitelist[_address] = true;
    }
  }

  // Removes multiple addresses from whitelist
  function removeFromPresaleWhitelist(address[] memory _addresses)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < _addresses.length; i++) {
      address _address = _addresses[i];
      presaleWhitelist[_address] = false;
    }
  }

  //-- Public Functions --//

  // Mint token - requires amount
  function mint(uint256 _amount) external payable whenOwnerOrSaleActive {
    require(_amount > 0, 'Must mint at least one');

    // Check there enough mints left to mint
    require(getMintsLeft() >= _amount, 'Minting would exceed max supply');

    // Set cost to mint
    uint256 costToMint = 0;

    bool isOwner = owner() == _msgSender();

    if (!isOwner) {
      // If pre sale is active, make sure user is on whitelist
      if (preSaleActive) {
        require(presaleWhitelist[_msgSender()], 'Must be on whitelist');
      }

      // Set cost to mint
      costToMint = mintCost * _amount;

      // Get current address total balance
      uint256 currentWalletAmount = super.balanceOf(_msgSender());

      // Check current token amount and mint amount is not more than max wallet amount
      require(
        currentWalletAmount.add(_amount) <= maxWalletAmount,
        'Requested amount exceeds maximum mint amount per wallet'
      );
    }

    // Check cost to mint, and if enough ETH is passed to mint
    require(costToMint <= msg.value, 'ETH amount sent is not correct');

    for (uint256 i = 0; i < _amount; i++) {
      // Increment token id
      _tokenIds.increment();

      // Safe mint
      _safeMint(_msgSender(), _tokenIds.current());
    }

    // Send mint cost to payment address
    Address.sendValue(payable(paymentAddress), costToMint);

    // Return unused value
    if (msg.value > costToMint) {
      Address.sendValue(payable(_msgSender()), msg.value.sub(costToMint));
    }
  }

  // Get mints left
  function getMintsLeft() public view returns (uint256) {
    uint256 currentSupply = super.totalSupply();
    return TOTAL_TOKENS.sub(currentSupply);
  }

  // Set mint cost
  function setMintCost(uint256 _cost) external onlyOwner {
    mintCost = _cost;
  }

  // Set max wallet amount
  function setMaxWalletAmount(uint256 _amount) external onlyOwner {
    maxWalletAmount = _amount;
  }

  // Set payment address
  function setPaymentAddress(address _address) external onlyOwner {
    paymentAddress = _address;
  }

  // Set royalty wallet address
  function setRoyaltyAddress(address _address) external onlyOwner {
    royaltyAddress = _address;
  }

  // Set royalty basis points
  function setRoyaltyBasisPoints(uint256 _basisPoints) external onlyOwner {
    royaltyBasisPoints = _basisPoints;
    emit RoyaltyBasisPoints(_basisPoints);
  }

  // Set base URI
  function setBaseURI(string memory _uri) external onlyOwner {
    baseTokenURI = _uri;
  }

  // Token URI (baseTokenURI + tokenId)
  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(_exists(_tokenId), 'Nonexistent token');

    return string(abi.encodePacked(_baseURI(), _tokenId.toString()));
  }

  // Contract metadata URI - Support for OpenSea: https://docs.opensea.io/docs/contract-level-metadata
  function contractURI() public view returns (string memory) {
    return string(abi.encodePacked(_baseURI(), 'contract'));
  }

  // Override supportsInterface - See {IERC165-supportsInterface}
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(_interfaceId);
  }

  // Pauses all token transfers - See {ERC721Pausable}
  function pause() external virtual onlyOwner {
    _pause();
  }

  // Unpauses all token transfers - See {ERC721Pausable}
  function unpause() external virtual onlyOwner {
    _unpause();
  }

  //-- Internal Functions --//

  // Get base URI
  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }

  // Before all token transfer
  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(_from, _to, _tokenId);
  }
}
