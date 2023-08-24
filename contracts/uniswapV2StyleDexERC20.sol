//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './interfaces/IERC20.sol';
/*
 - ・トークンのイメージ
 - 利用者全員分の何らか(お金)のやり取りをひたすら記録する世界に1つだけの記録帳(通帳)。
 - 利用者が各々通帳を持ってるわけじゃない。1つしかない。
*/

contract uniswapV2StyleDexERC20 is IERC20 {
    uint256 internal _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _owner = msg.sender;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns(uint256){
        return _allowances[owner][spender];
    }

    function _mint(address account, uint256 amount) internal {
        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        _balances[account] = _balances[account] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(account, address(0), amount);        
    }

    function transfer(address recipient, uint256 amount) external returns(bool){
        require(recipient != address(0), "transfer to the zero address is not allowed");
        address sender = msg.sender;
        require(_balances[sender] >= amount, "transfer amount cannot exceed balance");
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns(bool){
        require(spender != address(0), "approve to the zero address is not allowed");
        address owner = msg.sender;
        _allowances[owner][spender] = amount;
        emit Approval (owner, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) external returns(bool){
        require(recipient != address(0), "transfer to the zero address is not allowed");
        require(_balances[sender] >= amount, "transfer amount cannot exceed balance");
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);

        address spender = msg.sender;
        require(_allowances[sender][spender] >= amount, "insufficient allowance");
        _allowances[sender][spender] = _allowances[sender][spender] - amount;
        emit Approval(sender, spender, _allowances[sender][spender]);

        return true;
    }
}