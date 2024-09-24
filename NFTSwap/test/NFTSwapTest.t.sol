// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFTSwap} from "../src/NFTSwap.sol";
import {MockERC721} from "../script/MockERC721.sol";
import {NFTSwapDeploy} from "../script/NFTSwapDeploy.s.sol";

contract NFTSwapTest is Test {
    NFTSwap public nftSwap;
    MockERC721 public mockNFT;

    address public owner = makeAddr("owner");
    address public buyer = makeAddr("buyer");

    uint256 public tokenId = 1;
    uint256 public price = 1 ether;

    function setUp() public {
        mockNFT = new MockERC721();
        NFTSwapDeploy nftSwapDeploy = new NFTSwapDeploy();
        nftSwap = nftSwapDeploy.deployNFTSwap(address(mockNFT));

        // 为买家铸造一个NFT
        mockNFT.mint(owner, tokenId);

        // 为买家提供10 ether
        deal(buyer, 10 ether);

        // 买家授权NFTSwap合约
        vm.startPrank(owner);
        mockNFT.approve(address(nftSwap), tokenId);
        vm.stopPrank();
    }

    function testListNFT() public {
        vm.startPrank(owner);

        // NFT 清单
        nftSwap.listNFT(address(mockNFT), tokenId, price);

        // 验证NFT是否已经被上架
        (address nftOwner, uint256 nftPrice) = nftSwap.nftList(address(mockNFT), tokenId);
        assertEq(nftOwner, owner);
        assertEq(nftPrice, price);

        vm.stopPrank();
    }

    function testListFailsIfTokenNotExists() public {
        vm.startPrank(owner);

        uint256 invalidTokenId = 2;
        mockNFT.mint(owner, invalidTokenId);
        vm.expectRevert(NFTSwap.NFTSwap__NFTIsNotApproved.selector);
        nftSwap.listNFT(address(mockNFT), invalidTokenId, price);

        vm.stopPrank();
    }
    
    function testListFailsIfPriceIsZero() public {
        vm.startPrank(owner);
        
        vm.expectRevert(NFTSwap.NFTSwap__PriceIsZero.selector);
        nftSwap.listNFT(address(mockNFT), tokenId, 0);
        
        vm.stopPrank();
    }

    function testListFailsIfTokenAlreadyListed() public {
        vm.startPrank(owner);

        nftSwap.listNFT(address(mockNFT), tokenId, price);
        vm.expectRevert(NFTSwap.NFTSwap__NFTAlreadyListed.selector);
        nftSwap.listNFT(address(mockNFT), tokenId, price);

        vm.stopPrank();
    }

    function testRevokeNFT() public {
        vm.startPrank(owner);
        nftSwap.listNFT(address(mockNFT), tokenId, price);
        nftSwap.revokeNFT(address(mockNFT), tokenId);

        // Verify the NFT is revoked
        (address owner1,) = nftSwap.nftList(address(mockNFT), tokenId);
        assertEq(owner1, address(0));

        vm.stopPrank();
    }

    function testUpdatePrice() public {
        uint256 newPrice = 2 ether;

        vm.startPrank(owner);
        nftSwap.listNFT(address(mockNFT), tokenId, price);
        nftSwap.updatePrice(address(mockNFT), tokenId, newPrice);

        // Verify the price has been updated
        (, uint256 nftPrice) = nftSwap.nftList(address(mockNFT), tokenId);
        assertEq(nftPrice, newPrice);

        vm.stopPrank();
    }

    function testUpdatePriceFailsIfIsNotOwner() public {
        uint256 newPrice = 2 ether;

        vm.startPrank(owner);
        nftSwap.listNFT(address(mockNFT), tokenId, price);
        vm.stopPrank();

        vm.expectRevert(NFTSwap.NFTSwap__NotOwner.selector);
        vm.startPrank(buyer);
        nftSwap.updatePrice(address(mockNFT), tokenId, newPrice);
        vm.stopPrank();
    }

    function testPurchaseNFT() public {
        vm.startPrank(owner);
        nftSwap.listNFT(address(mockNFT), tokenId, price);
        vm.stopPrank();

        // Buyer purchases the NFT
        vm.startPrank(buyer);
        nftSwap.purchaseNFT{value: price}(address(mockNFT), tokenId);
        vm.stopPrank();

        // Verify that the NFT is transferred to the buyer
        assertEq(mockNFT.ownerOf(tokenId), buyer);
    }

    function testPurchaseFailsIfNotEnoughETH() public {
        vm.startPrank(owner);
        nftSwap.listNFT(address(mockNFT), tokenId, price);
        vm.stopPrank();

        // Buyer tries to purchase the NFT with insufficient ETH
        vm.startPrank(buyer);
        vm.expectRevert(NFTSwap.NFTSwap__NotEnoughPrice.selector);
        nftSwap.purchaseNFT{value: 0.5 ether}(address(mockNFT), tokenId);
        vm.stopPrank();
    }
}
