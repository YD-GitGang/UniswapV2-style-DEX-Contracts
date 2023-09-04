import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { ContractFactory, Contract } from "ethers";

describe('uniswapV2StyleDexLibrary', function () {
    async function deployLibFixture() {
        const Lib: ContractFactory = await ethers.getContractFactory("uniswapV2StyleDexLibraryTest");
        const lib: Contract = await Lib.deploy();
        await lib.deployed();
        return { lib }
    }

    describe('quote', async function () {
        it('get quote', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            const amountA: BigNumber = BigNumber.from(2).pow(200);  // 2^200
            const reserveA: BigNumber = BigNumber.from(123);
            const reserveB: BigNumber = BigNumber.from(2).pow(50).add(1);  // 2^50 + 1
            const amountB: BigNumber = amountA.mul(reserveB).div(reserveA);  // amountA * reserveB / reserveA
            expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        });

        // it('type(number&BigNumber) test 01', async function() {
        //     const { lib } = await loadFixture(deployLibFixture);
        //     const amountA: BigNumber = BigNumber.from(2).pow(200);
        //     const reserveA: BigNumber = BigNumber.from(123);
        //     const reserveB: BigNumber = BigNumber.from(2).pow(50).add(1);
        //     const amountB: BigNumber = amountA * reserveB / reserveA; // (※1)
        //     expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        //     /*
        //      - (※1)ethersからインポートしたBigNumberは*とか/みたいな演算子と一緒に使えない気がするが...違うだろうか。
        //     */
        // });

        // it('type(number&BigNumber) test 02', async function() {
        //     const { lib } = await loadFixture(deployLibFixture);
        //     const amountA = 2**200; // 9007199254740991より大きいからBigNumber型(bigint型?)にしないとダメなのかな多分。
        //     const reserveA = 123;
        //     const reserveB = 2**50 + 1;
        //     const amountB: BigNumber = BigNumber.from(amountA).mul(reserveB).div(reserveA);
        //     expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        // });

        it('type(number&BigNumber) test 03', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            const amountA = 2**20;
            const reserveA = 123;
            const reserveB = 2**50 + 1;
            const amountB: BigNumber = BigNumber.from(amountA).mul(reserveB).div(reserveA);
            expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        });
    
        it('type(number&BigNumber) test 04', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            const amountA = 2**2;
            const reserveA = 16;
            const reserveB = 2**2;
            const amountB = amountA * reserveB / reserveA;
            expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        });
    
        // it('type(number&BigNumber) test 05', async function() {
        //     const { lib } = await loadFixture(deployLibFixture);
        //     const amountA = 2**2;
        //     const reserveA = 100;
        //     const reserveB = 2**2;
        //     const amountB = amountA * reserveB / reserveA; // (※2)
        //     expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        //     /*
        //      - (※2)はfunction quote (uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB)　の返り値が
        //      - uintだから小数はダメってことかな多分。                
        //     */
        // });

        // it('type(number&BigNumber) test 06', async function() {
        //     const { lib } = await loadFixture(deployLibFixture);
        //     const amountA = 2**2;
        //     const reserveA = 123;
        //     const reserveB = 2**2;
        //     const amountB = amountA.mul(reserveB).div(reserveA); // (※3)
        //     expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        //     /*
        //      - (※3)Number型(amountA)にmul関数もdiv関数もないからBigNumber型(bigint型?)にする必要があるのにしてないからダメってことかな多分。
        //      - 21行目みたいになら大丈夫。
        //     */
        // })
    
        it('type(number&BigNumber) test 07', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            const amountA = 2**2;
            const reserveA = 123;
            const reserveB = 2**2;
            const amountB: BigNumber = BigNumber.from(amountA).mul(reserveB).div(reserveA);
            expect(await lib.quote(amountA, reserveA, reserveB)).to.eq(amountB);
        })
    });

    describe('getAmountOut', async function() {
        it('get amountout', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            const amountIn: BigNumber = BigNumber.from(2).pow(100).add(1)
            const reserveIn: BigNumber = BigNumber.from(123)
            const reserveOut: BigNumber = BigNumber.from(2).pow(50).add(1)
            const amountInWithFee: BigNumber = amountIn.mul(997)
            const numerator: BigNumber = amountInWithFee.mul(reserveOut)
            const denominator: BigNumber = (reserveIn.mul(1000)).add(amountInWithFee)
            const amountOut: BigNumber = numerator.div(denominator)
            expect(await lib.getAmountOut(amountIn, reserveIn, reserveOut)).to.eq(amountOut)
        });

        it('insufficient input amount', async () => {
            const { lib } = await loadFixture(deployLibFixture);
            await expect(lib.getAmountOut(0, 100, 200)).to.be.revertedWith('uniswapV2StyleDexLibrary: INSUFFICIENT_INPUT_AMOUNT');
        });

        it('insufficient liquidity', async function() {
            const { lib } = await loadFixture(deployLibFixture);
            await expect(lib.getAmountOut(100, 0, 200)).to.be.revertedWith('uniswapV2StyleDexLibrary: INSUFFICIENT_LIQUIDITY');
        });
    });
})