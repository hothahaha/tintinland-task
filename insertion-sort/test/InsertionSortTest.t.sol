// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InsertionSortDeploy} from "../script/InsertionSortDeploy.s.sol";

contract InsertionSortTest is Test {
    uint[] private expectedArr = [1, 2, 3, 5];
    uint[] private tempArr;

    function setUp() public {
        InsertionSortDeploy deploy = new InsertionSortDeploy();
        tempArr = deploy.deploy();
    }

    function test_arrSorted() public {
        assertEq(tempArr, expectedArr);
    }
}
