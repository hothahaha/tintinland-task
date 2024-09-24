// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {NFTSwap} from "../src/NFTSwap.sol";

contract NFTSwapDeploy is Script {
    function run() public {}

    function deployNFTSwap(address _nftAddress) public returns (NFTSwap) {
        NFTSwap nftSwap = new NFTSwap(_nftAddress);
        return nftSwap;
    }
}
