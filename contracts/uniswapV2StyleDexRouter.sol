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

        if (reserveA == 0 && reserveB == 0) {
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
            /*
             - ・ _addLiquidityのイメージ。流動性提供者がUI画面で一方のトークンの希望提供量を入力。するとその瞬間のトークン比
             - からもう片方のトークンの想定提供量が計算される。提供量がこの時点であくまで希望や想定なのは流動性提供者が
             - UIを操作し確定ボタンを押し関数が実行されるまでのわずかな間も世界の誰かがこのプールでスワップをしプールのトークン
             - 比が変動しているため、希望とは若干違う提供量になるからだ。関数が実行され実際の提供量を計算する際、流動性提供者が
             - UI画面で確認した希望(想定)提供量を最大量としどちらのトークンもそれ以下の提供量になるように再計算される。流動性
             - 提供者からすれば、想定より少なくなる分には構わないが想定を上回り足りない分を勝手に自分のウォレットから抜き取られるのは
             - 迷惑な話というわけだ。(例) 現在のプール内のトークン比はトークンXの方がトークンYより少し多い程度と仮定。UI画面で
             - トークンXの希望提供量を入力するとその瞬間のトークン比から計算されたトークンYの提供量がUI画面に映し出される。その
             - 提供量に納得し確定ボタンを押して関数が実行されるが誰かのスワップによりプール内のトークン比はトークンYの方がトークン
             - Xより少し多くなっていて実際の提供量が変動。希望したトークンXの量を提供するにはトークンYの提供量がUIで確認した時
             - の量よりもさらに必要になる。しかしそのさらに必要になったトークンYを流動性提供者のウォレットから勝手に抜き取るわ
             - けにはいかない。そこで、UIで確認したトークンYの量を提供するとしてトークンXの提供量を新たに再計算する。すると、
             - トークンXの提供量は希望量より減りトークンYは希望通りの提供量という結果になる。
             -
             - ・ 誰もpoolのトークンをswapせずDesired通りにpoolに預け入れることが出来たら,
             - (※3)側でも(※4)側でもどっちでも問題ないから(※3)と(※4)の条件式の
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
    
    function swapTokenPair (
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns(uint amountOut) {
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenIn, tokenOut);
        require(pool != address(0), 'uniswapV2StyleDexRouter: POOL_DOES_NOT_EXIST');

        {  // Avoid stack too deep error
        uint reserve0 = uniswapV2StyleDexPool(pool).reserve0();
        uint reserve1 = uniswapV2StyleDexPool(pool).reserve1();
        (uint reserveIn, uint reserveOut) = tokenIn < tokenOut ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOut = uniswapV2StyleDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        }

        require(amountOut >= amountOutMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        //bool success = uniswapV2StyleDexERC20(tokenIn).transferFrom(msg.sender, pool, amountIn);
        bool success = IERC20(tokenIn).transferFrom(msg.sender, pool, amountIn);
        require(success, 'uniswapV2StyleDexRouter: TOKEN_IN_TRANSFER_FAILED');
        (uint amount0Out, uint amount1Out) = tokenIn < tokenOut ? (uint(0), amountOut) : (amountOut, uint(0));  // (※1)
        uniswapV2StyleDexPool(pool).swap(amount0Out, amount1Out, to);
        /*
         - (※1) uint(0): 0が256bitの符号なし整数であることを明示。でないとuint8と判断される。
         - エラー参考: True expression's type tuple(uint8,uint256) does not match false expression's type tuple(uint256,uint8).
        */
    }

    function getAmountOut (uint amountIn, uint reserveIn, uint reserveOut) external pure returns(uint amountOut) {
        amountOut = uniswapV2StyleDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }
}