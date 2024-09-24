// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract NFTSwap is IERC721Receiver {
    IERC721 public nftContract;

    /*////////////////////////////////////////////////////////////////////////
                                    ERRORS
    ////////////////////////////////////////////////////////////////////////*/
    error NFTSwap__NotOwner();
    error NFTSwap__PriceIsZero();
    error NFTSwap__NFTAlreadyListed();
    error NFTSwap__NFTNotListed();
    error NFTSwap__NotEnoughPrice();
    error NFTSwap__NFTIsNotApproved();

    /*////////////////////////////////////////////////////////////////////////
                                State Variables
    ////////////////////////////////////////////////////////////////////////*/

    // Order 结构体
    struct Order {
        address owner;
        uint256 price;
    }

    constructor(address _nftContract) {
        nftContract = IERC721(_nftContract);
    }

    uint256 private constant AMOUNT_ZERO = 0;

    // tokenId => Order 映射
    mapping(address => mapping(uint256 => Order)) public nftList;

    /*////////////////////////////////////////////////////////////////////////
                                    EVENTS
    ////////////////////////////////////////////////////////////////////////*/
    event Listed(uint256 indexed tokenId, address indexed owner, uint256 price);
    event Revoked(uint256 indexed tokenId, address indexed owner);
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event Purchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    /*////////////////////////////////////////////////////////////////////////
                                 MODIFIERS
    ////////////////////////////////////////////////////////////////////////*/

    modifier nftIsListedAndOwner(address _nftAddress, uint256 _tokenId) {
        Order storage order = nftList[_nftAddress][_tokenId];
        if (order.owner != msg.sender) {
            revert NFTSwap__NotOwner();
        }
        _;
    }

    fallback() external payable {}

    /*////////////////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////*/
    /**
     * @dev NFT 清单
     */
    function listNFT(address _nftAddress, uint256 _tokenId, uint256 _price) external {
        if (nftList[_nftAddress][_tokenId].owner != address(0)) {
            revert NFTSwap__NFTAlreadyListed();
        }
        if (nftContract.getApproved(_tokenId) != address(this)) {
            revert NFTSwap__NFTIsNotApproved();
        }
        if (_price == AMOUNT_ZERO) {
            revert NFTSwap__PriceIsZero();
        }

        // 将 NFT 转移给本合约
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        nftList[_nftAddress][_tokenId] = Order({owner: msg.sender, price: _price});

        emit Listed(_tokenId, msg.sender, _price);
    }

    /**
     * @dev 撤单
     */
    function revokeNFT(address _nftAddress, uint256 _tokenId) external nftIsListedAndOwner(_nftAddress, _tokenId) {
        delete nftList[_nftAddress][_tokenId];

        emit Revoked(_tokenId, msg.sender);
    }

    /**
     * @dev 更新价格
     */
    function updatePrice(address _nftAddress, uint256 _tokenId, uint256 _newPrice)
        external
        nftIsListedAndOwner(_nftAddress, _tokenId)
    {
        Order storage order = nftList[_nftAddress][_tokenId];
        order.price = _newPrice;

        emit PriceUpdated(_tokenId, _newPrice);
    }

    /**
     * @dev 购买 NFT
     */
    function purchaseNFT(address _nftAddress, uint256 _tokenId) external payable {
        Order storage order = nftList[_nftAddress][_tokenId];
        if (msg.value < order.price) {
            revert NFTSwap__NotEnoughPrice();
        }

        // 将NFT转移给买家
        nftContract.safeTransferFrom(address(this), msg.sender, _tokenId);
        // 将标价金额转移给卖家
        payable(order.owner).transfer(msg.value);
        // 将支付的多余金额返回给买家
        payable(msg.sender).transfer(msg.value - order.price);
        // 清空信息
        delete nftList[_nftAddress][_tokenId];

        emit Purchased(_tokenId, msg.sender, order.owner, order.price);
    }

    function onERC721Received(address, /*operator*/ address, /*from*/ uint256, /*tokenId*/ bytes calldata /*data*/ )
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
