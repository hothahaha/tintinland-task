// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

contract InsertionSort is Script {
    // [2, 5, 3, 1]
    // 第一次for的第一次while [2, 5, 1, 1]
    // 第一次for结束 [2, 5, 1, 3]
    // 第二次for 第一次while [2, 1, 1, 3]
    // 第二次for 第二次while [2, 1, 3, 1]
    // 第二次for结束 [2, 1, 3, 5]
    // 第三次for 第一次while [1, 1, 3, 5]
    // 第三次for结束 [1, 2, 3, 5]

    function sort(uint[] memory arr) public returns (uint[] memory) {
        uint[] memory temp = arr;
        for (uint i = temp.length - 1; i > 0; i--) {
            uint j = i - 1;
            uint key = temp[j];
            while (j < temp.length - 1 && temp[j + 1] < key) {
                temp[j] = temp[j + 1];
                j++;
            }
            temp[j] = key;
        }
        return temp;
    }
}
