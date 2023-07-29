//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './libraries/uniswapV2StyleDexLibrary.sol';
import './interfaces/IERC20.sol';
import './uniswapV2StyleDexPool.sol';
import './uniswapV2StyleDexFactory.sol';

contract uniswapV2StyleDexRouter {
    address public immutable factory; 

    constructor(address _factory) {
        factory = _factory;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'uniswapV2StyleDexRouter: EXPIRED');
        _;
    }

    function _addLiquidity(
        address pool,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view returns (uint amountA, uint amountB) {
        uint reserve0 = uniswapV2StyleDexPool(pool).reserve0();
        uint reserve1 = uniswapV2StyleDexPool(pool).reserve1();
        (uint reserveA, uint reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);

        if (reserveA == 0 && reserveB ==0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = uniswapV2StyleDexLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) { //(※3)
                require(amountBOptimal >= amountBMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = uniswapV2StyleDexLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired); //(※4)
                require(amountAOptimal >= amountAMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
            /**
             * - 誰もpoolのトークンをswapせずDesired通りにpoolに預け入れることが出来たら,
             * - (※3)側でも(※4)側でもどっちでも問題ないから(※3)と(※4)の条件式の
               - 両方ともに = があってもokってことだろうか? (※4)の =　なくてもいいような。
             */
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity){
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB);
        if (pool == address(0)) {
            uniswapV2StyleDexFactory(factory).createPool(tokenA, tokenB); //(※1)
            pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB); //(※2)
            //(※1)の戻り値poolだから(※2)書かずに、(※1)を pool = uniswapV2StyleDexFactory(factory).createPool(tokenA, tokenB) としてもOK。
        }
        (amountA, amountB) = _addLiquidity(pool, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        bool successA = IERC20(tokenA).transferFrom(msg.sender, pool, amountA);
        require(successA, 'uniswapV2StyleDexRouter: TOKEN_A_TRANSFER_FAILED');
        bool successB = IERC20(tokenB).transferFrom(msg.sender, pool, amountB);
        require(successB, 'uniswapV2StyleDexRouter: TOKEN_B_TRANSFER_FAILED');

        liquidity = uniswapV2StyleDexPool(pool).mint(to);
    }

    function removeLiquidity (
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns(uint amountA, uint amountB) {
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB);
        require(pool != address(0), 'uniswapV2StyleDexRouter: POOL_DOES_NOT_EXIST');

        uniswapV2StyleDexPool(pool).transferFrom(msg.sender, pool, liquidity);
        (uint amount0, uint amount1) = uniswapV2StyleDexPool(pool).burn(to);
        
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_B_AMOUNT');
    }
}