//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library uniswapV2StyleDexLibrary {
    function quote (uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'uniswapV2StyleDexLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }
}