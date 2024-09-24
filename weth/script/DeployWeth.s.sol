// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {WETH} from "../src/WETH.sol";

contract DeployWeth {
    function run() external returns (WETH) {
        WETH weth = new WETH();
        return weth;
    }
}
