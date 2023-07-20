//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './libraries/Math.sol';
import './interfaces/IERC20.sol';
import './uniswapV2StyleDexERC20.sol';

contract uniswapV2StyleDexPool is uniswapV2StyleDexERC20("uniswapV2StyleDex", "UDX", 18) {
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    address immutable public factory;
    address public token0;
    address public token1;
    uint public reserve0;
    uint public reserve1;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'uniswapV2StyleDexPool: INITIALIZATION_FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to) external returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - reserve0;
        uint amount1 = balance1 - reserve1;
        
        /*
         - ステートヴァリアブルをpublicにすると他のコントラクトで使うときゲッター関数として後ろに()つけて使うかけど、
         - このコントラクトはuniswapV2StyleDexERC20を継承してるからinternalの _totalSupply の後ろに()いらないのかな多分。
         -  _totalSupply * hoge　はいけるけど totalSupply() * hoge はダメでやるならtotalSupply()を変数に入れてからにしなきゃ
         - いけないから、それがてまで_totalSupplyをinternalにしたのかな多分。
        */
        if (_totalSupply == 0) {
            require(amount0 * amount1 > MINIMUM_LIQUIDITY * MINIMUM_LIQUIDITY, 'uniswapV2StyleDexPool: BELOW_MINIMUM_LIQUIDITY');
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * _totalSupply / reserve0, amount1 * _totalSupply / reserve1);
        }
        require(liquidity > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        reserve0 = balance0;
        reserve1 = balance1;
        emit Mint (msg.sender, amount0, amount1);
    }
    
    function burn (address to) external returns(uint amount0, uint amount1) {
        IERC20 token0Contract = IERC20(token0);
        IERC20 token1Contract = IERC20(token1);
        
        uint liquidity = _balances[address(this)];
        uint balance0 = token0Contract.balanceOf(address(this));
        uint balance1 = token1Contract.balanceOf(address(this));
        amount0 = balance0 * liquidity / _totalSupply;
        amount1 = balance1 * liquidity / _totalSupply;
        require(amount0 > 0 && amount1 > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY_BURNED');

        _burn(address(this), liquidity);
        bool success0 = token0Contract.transfer(to, amount0);
        require(success0, 'uniswapV2StyleDexPool: TOKEN0_TRANSFER_FAILED');
        bool success1 = token1Contract.transfer(to, amount1);
        require(success1, 'uniswapV2StyleDexPool: TOKEN1_TRANSFER_FAILED');

        reserve0 = token0Contract.balanceOf(address(this));
        reserve1 = token1Contract.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1, to);
    }
}