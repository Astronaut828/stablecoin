// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

error StableCoin__InvalidAmount();
error StableCoin__InsufficientBalance();
error StableCoin__InvalidAddress();

contract StableCoin is ERC20, Ownable {
    constructor() ERC20("MyUSD", "mUSDC") Ownable(msg.sender) {}

    function burnFrom(address account, uint256 amount) external onlyOwner {
        uint256 balance = balanceOf(account);
        if (amount == 0) {
            revert StableCoin__InvalidAmount();
        }
        if (balance < amount) {
            revert StableCoin__InsufficientBalance();
        }
        _burn(account, amount);
    }

    function mintTo(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert StableCoin__InvalidAddress();
        }
        if (amount == 0) {
            revert StableCoin__InvalidAmount();
        }
        _mint(to, amount);
        return true;
    }
}
