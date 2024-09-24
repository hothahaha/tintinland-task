// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AMM} from "../src/AMM.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {DAI, WETH} from "../src/Constants.sol";

contract AMMTest is Test {
    AMM public amm;
    
    IERC20 private constant weth = IERC20(WETH);
    IERC20 private constant dai = IERC20(DAI);
    
    address private USER = makeAddr("user");
    
    uint256 private constant START_WETH_BALANCE = 100 * 1e18;
    uint256 private constant START_DAI_BALANCE = 1000000 * 1e18;
    
    uint256 private liquidity;
    
    function setUp() public {
        amm = new AMM(WETH, DAI);
        
        deal(WETH, USER, START_WETH_BALANCE);
        vm.startPrank(USER);
        weth.approve(address(amm), type(uint256).max);
        vm.stopPrank();
        
        deal(DAI, USER, START_DAI_BALANCE);
        vm.startPrank(USER);
        dai.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }
    
    function testAddLiquidityErrorWhenLiquidityIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(AMM.AMM__Insufficient_Liquidity_Minted.selector);
        liquidity = amm.addLiquidity({
            amountADesired : 0,
            amountBDesired : START_DAI_BALANCE
        });
        vm.stopPrank();
    }
    function testAddLiquidityWithCorrectArgs() public {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, false, address(amm));
        emit AMM.Mint(USER, START_WETH_BALANCE, START_DAI_BALANCE);
        liquidity = amm.addLiquidity({
            amountADesired : START_WETH_BALANCE,
            amountBDesired : START_DAI_BALANCE
        });
        vm.stopPrank();
    }
    
    function testAddLiquidity() public {
        vm.prank(USER);
        liquidity = amm.addLiquidity({
            amountADesired : START_WETH_BALANCE,
            amountBDesired : START_DAI_BALANCE
        });
        console.log("LP : ", liquidity);
        console.log("LP1 : ", amm.balanceOf(USER));
        assertGe(amm.balanceOf(USER), 0);
    }
    
    function testRemoveLiquidityErrorWhenAmountIsZero() public {
        vm.startPrank(USER);
        liquidity = amm.addLiquidity({
            amountADesired : START_WETH_BALANCE,
            amountBDesired : START_DAI_BALANCE
        });
        vm.expectRevert(AMM.AMM__Insufficient_Liquidity_Burned.selector);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(0);
        vm.stopPrank();
    }
    
    function testRemoveLiquidity() public {
        vm.startPrank(USER);
        liquidity = amm.addLiquidity({
            amountADesired : START_WETH_BALANCE,
            amountBDesired : START_DAI_BALANCE
        });
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(liquidity);
        vm.stopPrank();
        console.log("Amount A : ", amountA);
        console.log("Amount B : ", amountB);
        
        assertEq(amm.balanceOf(USER), 0);
    }
    
}
