//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library uniswapV2StyleDexLibrary {
    function quote (uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    /*
     - visibilityはinternal。このライブラリはこれを呼び出しているコントラクトの中にコードとして埋め込んでデプロイするため。
     - internal以外はリンクが切れるのでNG。
    */
    function getAmountOut (uint amountIn, uint reserveIn, uint reserveOut) internal pure returns(uint amountOut) {
        require(amountIn > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}