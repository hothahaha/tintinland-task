// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {InsertionSort} from "../src/InsertionSort.sol";

contract InsertionSortDeploy {
    uint[] private arr = [1, 2, 3, 5];

    function run() public {}

    function deploy() public returns (uint[] memory) {
        InsertionSort insertionSort = new InsertionSort();
        return insertionSort.sort(arr);
    }
}
