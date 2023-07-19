//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import '../interfaces/IERC20.sol';


contract TokenTest is IERC20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _owner = msg.sender;
        _balances[_owner] = _totalSupply;
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

    function mint(address account, uint256 amount) external {
        require(msg.sender == _owner, "Only contract owner can call mint");
        require(account != address(0), "mint to the zero address is not allowed");
        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(msg.sender == _owner, "Only contract owner can call burn");
        require(account != address(0), "burn from the zero address is not allowed");
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