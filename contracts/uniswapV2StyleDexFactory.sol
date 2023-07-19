//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './uniswapV2StyleDexPool.sol';
import 'hardhat/console.sol';

contract uniswapV2StyleDexFactory {
    mapping(address => mapping(address => address)) public getPool;

    event PoolCreated(address indexed token0, address indexed token1, address pool);

    function createPool(address tokenA, address tokenB) external returns(address pool) {
        require(tokenA != tokenB, 'uniswapV2StyleDexFactory: IDENTICAL_TOKEN_ADDRESS');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'uniswapV2StyleDexFactory: ZERO_ADDRESS');
        require(getPool[token0][token1] == address(0), 'uniswapV2StyleDexFactory: TOKEN_POOL_EXISTS');
        
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        uniswapV2StyleDexPool poolContract = new uniswapV2StyleDexPool{salt: salt}();
        poolContract.initialize(token0,token1);

        pool = address(poolContract);
        getPool[token0][token1] = pool;
        getPool[token1][token0] = pool;
        emit PoolCreated(token0, token1, pool);
        console.log("[Hardhat Debug] pool created at", pool);
    }
}