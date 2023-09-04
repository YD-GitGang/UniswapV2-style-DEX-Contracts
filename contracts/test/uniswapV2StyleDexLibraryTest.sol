//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import '../libraries/uniswapV2StyleDexLibrary.sol';

contract uniswapV2StyleDexLibraryTest {
    function quote (uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        amountB = uniswapV2StyleDexLibrary.quote(amountA, reserveA, reserveB);
    }
    
    function getAmountOut (uint amountIn, uint reserveIn, uint reserveOut) public pure returns(uint amountOut) {
        amountOut = uniswapV2StyleDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }
}