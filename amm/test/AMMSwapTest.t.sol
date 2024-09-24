// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AMM} from "../src/AMM.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {DAI, WETH, MKR} from "../src/Constants.sol";

contract AMMSwapTest is Test {
    AMM public amm;
    
    IERC20 private constant weth = IERC20(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant mkr = IERC20(MKR);
    
    address private USER = makeAddr("user");
    
    uint112 private constant TOKEN0_RESERVE = 1e6 * 1e18;
    uint112 private constant TOKEN1_RESERVE = 1e9 * 1e18;
    uint256 private constant START_WETH_BALANCE = 100 * 1e18;
    uint256 private constant START_DAI_BALANCE = 1000000 * 1e18;
    uint256 private constant MIN_AMOUNT_OUT = 1 * 1e18;
    
    uint256 private liquidity;
    
    function setUp() public {
        amm = new AMM(WETH, DAI);
        
        deal(WETH, USER, START_WETH_BALANCE);
        vm.startPrank(USER);
        weth.approve(address(amm), type(uint256).max);
        vm.stopPrank();
        
        deal(DAI, address(amm), TOKEN1_RESERVE);
        
        amm.initReserve(TOKEN0_RESERVE, TOKEN1_RESERVE);
    }
    
    function testSwapFailsWhenAmountInIsZero() public {
        vm.prank(USER);
        vm.expectRevert(AMM.AMM__SwapAmount_Cant_Be_Zero.selector);
        uint256 amountOut = amm.swap(0, weth, MIN_AMOUNT_OUT);
    }
    
    function testSwapFailsWhenTokenIsInvalid() public {
        vm.prank(USER);
        vm.expectRevert(AMM.AMM__Invalid_Token.selector);
        uint256 amountOut = amm.swap(START_WETH_BALANCE, mkr, MIN_AMOUNT_OUT);
    }
    
    function testSwap() public {
        vm.prank(USER);
        uint256 amountOut = amm.swap(START_WETH_BALANCE, weth, MIN_AMOUNT_OUT);
        
        console.log("DAI received: ", amountOut);
        assertGe(amountOut, MIN_AMOUNT_OUT);
    }
}
