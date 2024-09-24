// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployWeth} from "../script/DeployWeth.s.sol";
import {WETH} from "../src/WETH.sol";

contract WETHTest is Test {
    WETH public weth;
    
    address public USER = makeAddr("USER"); // 用户1
    
    uint256 public constant START_BALANCE = 10 ether; // 初始余额
    
    function setUp() public {
        // 部署 WETH 合约
        DeployWeth deployWeth = new DeployWeth();
        weth = deployWeth.run();
        
        // 为 USER 和 USER2 分配 10 ether
        deal(USER, START_BALANCE);
    }
    
    function testDepositFailsIfETHEqualsZero() public {
        vm.startPrank(USER);
        
        // 存入 0 ETH
        vm.expectRevert(WETH.WETH__MustBeMoreThanZero.selector);
        weth.deposit{value: 0}();
        
        vm.stopPrank();
    }
    
    function testDepositSuccess() public {
        // 模拟 USER 操作
        vm.startPrank(USER);
        
        uint256 initialBalance = weth.balanceOf(USER);
        uint256 initialEthBalance = USER.balance;
        
        // 存入 5 ETH
        weth.deposit{value: 5 ether}();
        
        // 检查 WETH 余额
        assertEq(weth.balanceOf(USER), initialBalance + 5 ether);
        
        // 检查 ETH 余额
        assertEq(USER.balance, initialEthBalance - 5 ether);
        
        vm.stopPrank();
    }
    
    function testWithdrawFailsIfAmountGeaterThanBalance() public {
        // 模拟 USER 操作
        vm.startPrank(USER);
        
        // 存入 2 ETH
        weth.deposit{value: 2 ether}();
        
        // 试图提取 5 WETH（超过余额）
        vm.expectRevert(WETH.WETH__WithdrawAmountExceedsBalance.selector);
        weth.withdraw(5 ether);
        
        vm.stopPrank();
    }
    
    function testWithdrawSuccess() public {
        // 模拟 USER 操作
        vm.startPrank(USER);
        
        // 先存入 5 ETH
        weth.deposit{value: 5 ether}();
        
        uint256 wethBalanceBefore = weth.balanceOf(USER);
        uint256 ethBalanceBefore = USER.balance;
        
        // 提取 3 WETH
        weth.withdraw(3 ether);
        
        // 检查 WETH 余额是否减少了 3
        assertEq(weth.balanceOf(USER), wethBalanceBefore - 3 ether);
        
        // 检查 ETH 余额是否增加了 3
        assertEq(USER.balance, ethBalanceBefore + 3 ether);
        
        vm.stopPrank();
    }
    
}
