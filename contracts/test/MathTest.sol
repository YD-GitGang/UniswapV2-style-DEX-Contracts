//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import '../libraries/Math.sol';

contract MathTest {
    function min (uint x, uint y) public pure returns (uint z) {
        z = Math.min(x, y);
    }

    function sqrt (uint y) public pure returns (uint z) {
        z = Math.sqrt(y);
    }
}