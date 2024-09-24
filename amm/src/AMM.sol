// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {Math} from '../libraries/Math.sol';
import {SafeMath} from '../libraries/SafeMath.sol';

contract AMM is ERC20 {
    /*////////////////////////////////////////////////////////////////////////
                                   ERRORS
    ////////////////////////////////////////////////////////////////////////*/
    error AMM__Insufficient_Liquidity_Minted();
    error AMM__Insufficient_Liquidity_Burned();
    error AMM__Insufficient_Input_Amount();
    error AMM__Insufficient_Liquidity();
    error AMM__SwapAmount_Cant_Be_Zero();
    error AMM__Invalid_Token();
    error AMM__AmountOut_Must_GreaterThan_OutMin();
    
    /*////////////////////////////////////////////////////////////////////////
                                    TYPE
    ////////////////////////////////////////////////////////////////////////*/
    using SafeMath for uint256;
    
    /*////////////////////////////////////////////////////////////////////////
                                STATE VARIABLES
    ////////////////////////////////////////////////////////////////////////*/
    IERC20 private token0;
    IERC20 private token1;
    
    uint112 private _reserve0;
    uint112 private _reserve1;
    
    /*////////////////////////////////////////////////////////////////////////
                                    EVENTS
    ////////////////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        address tokenIn,
        uint amount0Out,
        address tokenOut
    );
    
    constructor(address _token0, address _token1) ERC20("AMM", "AMM") {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }
    
    /*////////////////////////////////////////////////////////////////////////
                               EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////*/
    
    /**
     * @dev 增加流动性，用户输入 WETH 和 ERC20 代币的数量，按照池中的比例增加
     * @param amountADesired 要增加的 WETH 数量
     * @param amountBDesired 要增加的 ERC20 代币数量
     * @return liquidity 增加的流动性份额
     */
    function addLiquidity(uint amountADesired, uint amountBDesired) external returns (uint256 liquidity) {
        // @dev 省略UniswapV2Router02中_addLiquidity函数的实现
        // 参考 https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
        // @notice 省略了获取币对合约，获取币队合约中的存储量，通过乘积恒定公式计算出amount，再往币队合约中发送token和amount
        // 并为币队合约铸造流动性
        // @dev 参考 https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
        // 省略获取币对合约中两种代币的储备量reserve和在当前币对合约中两种代币的余量balance，用balance减去reserve计算出amount
        
        token0.transferFrom(msg.sender, address(this), amountADesired);
        token1.transferFrom(msg.sender, address(this), amountBDesired);
        
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // 忽略铸造攻击，不再减去MINIMUM_LIQUIDITY
            liquidity = Math.sqrt(amountADesired.mul(amountBDesired));
        } else {
            liquidity = Math.min(amountADesired.mul(_totalSupply) / _reserve0, amountBDesired.mul(_totalSupply) / _reserve1);
        }
        if(!(liquidity > 0)) {
            revert AMM__Insufficient_Liquidity_Minted();
        }
        // 省略时间加权平均值计算当前币对合约中储备量的计算
        _reserve0 = uint112(token0.balanceOf(address(this)));
        _reserve1 = uint112(token1.balanceOf(address(this)));
        // 为流动性提供者铸造LP
        _mint(msg.sender, liquidity);
        
        emit Mint(msg.sender, amountADesired, amountBDesired);
    }
    
    /**
     * @dev 移除流动性，用户输入 LP 份额，按照池中的比例减少
     * @param liquidity 要移除的流动性份额
     * @return amount0 移除的 WETH 数量
     * @return amount1 移除的 ERC20 代币数量
     */
    function removeLiquidity(uint liquidity) external returns (uint amount0, uint amount1) {
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));
        
        uint256 _totalSupply = totalSupply();
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        if(!(amount0 > 0 && amount1 > 0)) {
            revert AMM__Insufficient_Liquidity_Burned();
        }
        _burn(msg.sender, liquidity);
        
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        
        // 更新币对合约中的储备粮
        _reserve0 = uint112(token0.balanceOf(address(this)));
        _reserve1 = uint112(token1.balanceOf(address(this)));
        
        emit Burn(msg.sender, amount0, amount1, address(this));
    }
    
    function initReserve(uint112 reserve0, uint112 reserve1) external {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }
    
    // 通过常数乘积公式实现代币交换，用户输入 WETH 换取 ERC20 代币
    function swap(uint amountIn, IERC20 tokenIn, uint amountOutMin) external returns (uint amountOut) {
        IERC20 tokenOut;
        if(!(amountIn > 0)) {
            revert AMM__SwapAmount_Cant_Be_Zero();
        }
        if(tokenIn != token0 && tokenIn != token1) {
            revert AMM__Invalid_Token();
        }
        
        if(tokenIn == token0) {
            tokenOut = token1;
            amountOut = getAmountOut(amountIn, _reserve0, _reserve1);
        } else {
            tokenOut = token0;
            amountOut = getAmountOut(amountIn, _reserve1, _reserve0);
        }
        
        if(!(amountOut >= amountOutMin)) {
            revert AMM__AmountOut_Must_GreaterThan_OutMin();
        }
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        tokenOut.transfer(msg.sender, amountOut);
        
        _reserve0 = uint112(token0.balanceOf(address(this)));
        _reserve1 = uint112(token1.balanceOf(address(this)));
        emit Swap(msg.sender, amountIn, address(tokenIn), amountOut, address(tokenOut));
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        // 掉期费计算公式 dy = dx(1-f)y0 / x0 + dx(1-f)
        //      dx * 0.997 * y0
        // dy = ----------------
        //      x0 + dx * 0.997
        // dy = amountOut, dx = amountInWithFee, y0 = reserveOut, x0 = reserveIn
        // 这行代码计算带手续费的输入金额。假设手续费率为0.3%（即1 - 0.003 = 0.997），将 amountIn 乘以997得到 amountInWithFee
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        //          dx * 997 * y0
        // dy = ----------------------
        //       x0 * 1000 + dx * 997
        //
        //       dx * 997 / 1000 * y0
        //    = ----------------------
        //       x0 + dx * 997 / 1000
        amountOut = numerator / denominator;
    }
    
}
