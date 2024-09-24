// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    /*////////////////////////////////////////////////////////////////////////
                                    ERRORS
    ////////////////////////////////////////////////////////////////////////*/
    error WETH__MustBeMoreThanZero();
    error WETH__WithdrawAmountExceedsBalance();
    error WETH__TransferEthToUserFailed();
    
    // 定义合约名和代币符号
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    /**
     * @dev 合约接收 ETH 时触发 `deposit`。
     */
    receive() external payable {
        deposit();
    }
    
    fallback() external payable {
        deposit();
    }
    
    /*////////////////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////*/
    
    /**
     * @dev 用户向合约发送 ETH，并铸造等量的 WETH。
     */
    function deposit() public payable {
        // msg.value 是用户发送的 ETH 数量
        if(msg.value == 0) {
            revert WETH__MustBeMoreThanZero();
        }
        
        // 铸造等量的 WETH 给 msg.sender
        _mint(msg.sender, msg.value);
    }
    
    /**
     * @dev 用户销毁一定数量的 WETH 并取回等量的 ETH。
     * @param amount 要取回的 WETH 数量（等量的 ETH 会退还）。
     */
    function withdraw(uint256 amount) external {
        if(amount > balanceOf(msg.sender)) {
            revert WETH__WithdrawAmountExceedsBalance();
        }
        
        // 销毁用户的 WETH
        _burn(msg.sender, amount);
        
        // 向用户发送等量的 ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        if(!success) {
            revert WETH__TransferEthToUserFailed();
        }
    }
    
}
