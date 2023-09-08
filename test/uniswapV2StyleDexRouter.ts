import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import uniswapV2StyleDexPool from '../artifacts/contracts/uniswapV2StyleDexPool.sol/uniswapV2StyleDexPool.json';

const MINIMUM_LIQUIDITY = 10**3;

describe("uniswapV2StyleDexRouter", function() {
    async function step1Fixture() {
        const [owner, account1, account2] = await ethers.getSigners();

        // tokens
        const Token = await ethers.getContractFactory("TokenTest");
        const tokenA = await Token.deploy("tokenA", "A", 18, 1000000);
        const tokenB = await Token.deploy("tokenB", "B", 18, 1000000);
        await tokenA.transfer(account1.address, 200000);
        await tokenB.transfer(account1.address, 300000);
        await tokenA.transfer(account2.address, 400000);
        await tokenB.transfer(account2.address, 500000);

        // uniswapV2StyleDex Factory & Pool
        const Factory = await ethers.getContractFactory("uniswapV2StyleDexFactory");
        const factory = await Factory.deploy();
        await factory.deployed();
        await factory.createPool(tokenA.address, tokenB.address);
        const poolAddress = await factory.getPool(tokenA.address, tokenB.address);
        const pool = new ethers.Contract(poolAddress, uniswapV2StyleDexPool.abi, ethers.provider);

        // uniswapV2StyleDex Router
        const Router = await ethers.getContractFactory("uniswapV2StyleDexRouter");
        const router = await Router.deploy(factory.address);
        await router.deployed();

        return { owner, account1, account2, tokenA, tokenB, factory, pool, router };
    };

    it("check initial balances", async function() {
        const { owner, account1, account2, tokenA, tokenB, pool } = await loadFixture(step1Fixture);

        expect(await tokenA.balanceOf(owner.address)).to.eq(400000);
        expect(await tokenB.balanceOf(owner.address)).to.eq(200000);
        expect(await tokenA.balanceOf(account1.address)).to.eq(200000);
        expect(await tokenB.balanceOf(account1.address)).to.eq(300000);
        expect(await tokenA.balanceOf(account2.address)).to.eq(400000);
        expect(await tokenB.balanceOf(account2.address)).to.eq(500000);
        expect(await tokenA.balanceOf(pool.address)).to.eq(0);
        expect(await tokenB.balanceOf(pool.address)).to.eq(0);
    });

    it("check factory address", async function() {
        const { factory, router } = await loadFixture(step1Fixture);

        expect(await router.factory()).to.eq(factory.address);
    });

    async function step2Fixture() {
        const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step1Fixture);

        const deadline = Math.floor(Date.now() / 1000) + 60;

        const amountADesired = 100000;
        const amountBDesired = 200000;
        const [amount0Desired, amount1Desired] = tokenA.address < tokenB.address ? [amountADesired, amountBDesired] : [amountBDesired, amountADesired];

        // バビロニア法で計算される平方根は二乗してn(引数)以下になる最大の整数だが、標準ライブラリのMathはfloatを返す。
        const liquidity = Math.floor(Math.sqrt(amountADesired * amountBDesired) - MINIMUM_LIQUIDITY);
        const totalSupply = Math.floor(Math.sqrt(amountADesired * amountBDesired));

        await tokenA.connect(account1).approve(router.address, amountADesired);
        await tokenB.connect(account1).approve(router.address, amountBDesired);

        await expect(router.connect(account1).addLiquidity(
            tokenA.address, tokenB.address, amountADesired, amountBDesired, 0, 0, account1.address, deadline))
            .to.emit(pool, 'Mint')
            .withArgs(router.address, amount0Desired, amount1Desired)
            .to.emit(pool, 'Transfer')
            .withArgs(ethers.constants.AddressZero, account1.address, liquidity);
        expect(await tokenA.balanceOf(account1.address)).to.eq(100000); // 200000 - 100000
        expect(await tokenB.balanceOf(account1.address)).to.eq(100000); // 300000 - 200000
        expect(await tokenA.balanceOf(pool.address)).to.eq(amountADesired);
        expect(await tokenB.balanceOf(pool.address)).to.eq(amountBDesired);
        expect(await pool.balanceOf(account1.address)).to.eq(liquidity);
        expect(await pool.totalSupply()).to.eq(totalSupply);

        return { owner, account1, account2, tokenA, tokenB, factory, pool, router };
    };

    it("check balances after initial aaliquidity", async function() {
        const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

        expect(await tokenA.balanceOf(owner.address)).to.eq(400000);
        expect(await tokenB.balanceOf(owner.address)).to.eq(200000);
        expect(await tokenA.balanceOf(account1.address)).to.eq(100000);
        expect(await tokenB.balanceOf(account1.address)).to.eq(100000);
        expect(await tokenA.balanceOf(account2.address)).to.eq(400000);
        expect(await tokenB.balanceOf(account2.address)).to.eq(500000);

        expect(await tokenA.balanceOf(pool.address)).to.eq(100000);
        expect(await tokenB.balanceOf(pool.address)).to.eq(200000);

        //後で便利ということで、tokenA,Bのどっちがreseve0,1なのか分かってるテイ。
        expect(await pool.reserve0()).to.eq(100000);
        expect(await pool.reserve1()).to.eq(200000);

        expect(await pool.balanceOf(owner.address)).to.eq(0);
        expect(await pool.balanceOf(account1.address)).to.eq(140421); // Math.floor(Math.sqrt(amountADesired * amountBDesired) - MINIMUM_LIQUIDITY)
        expect(await pool.balanceOf(account2.address)).to.eq(0);
        expect(await pool.balanceOf(pool.address)).to.eq(0);
    });

    describe("addLiquidity", function() {
        it("test amountMin", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

            const deadline = Math.floor(Date.now() / 1000) + 60;

            let amountAMin;
            let amountBMin;

            const amountADesired = 100000;
            const amountBDesired = 100000;

            await tokenA.connect(account2).approve(router.address, amountADesired);
            await tokenB.connect(account2).approve(router.address, amountBDesired);

            //tokenA,Bのどっちがreseve0,1なのか分かってるテイ。
            amountAMin = 50001;
            amountBMin = 0;

            await expect(router.connect(account2).addLiquidity(
                tokenA.address, tokenB.address, amountADesired, amountBDesired, amountAMin, amountBMin, account1.address, deadline
                )).to.be.revertedWith('uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
            
            
            // ----------------------------------------

            amountAMin = 50000;
            amountBMin = 0;

            const totalSupply = await pool.totalSupply();

            // const [reserveA, reserveB] = tokenA.address < tokenB.address ? [await pool.reserve0(), await pool.reserve1()] : [await pool.reserve1(), await pool.reserve0()];
            const reserveB = tokenA.address < tokenB.address ? (await pool.reserve1()) : (await pool.reserve0());

            // liquidity2は型の実験してるだけだからスルーして下さい。
            const liquidity2 = totalSupply * amountBDesired / reserveB;  // (※1)
            console.log('########################');
            console.log(liquidity2); // Number型
            console.log('########################');
            const liquidity = totalSupply.mul(amountBDesired).div(reserveB);  // (※2)
            console.log('########################');
            console.log(liquidity); // BigNumber型
            console.log('########################');
            /*
             - (※1)ethersで取得したおそらくBigNumber型のtotalSupplyがなんで*とか/みたいな演算子と使えるんだろう...。
             - (※2)ethers経由で取得した値(totalSupply)は全てBigNumber型になるからBigNumber.from()使わなくてもmulとかdivが使えるのだろうか。
            */

            await expect(router.connect(account2).addLiquidity(
                tokenA.address, tokenB.address, amountADesired, amountBDesired, amountAMin, amountBMin, account1.address, deadline
                )).to.emit(pool, 'Mint')
                .withArgs(router.address, amountAMin, amountBDesired)
                .to.emit(pool, 'Transfer')
                .withArgs(ethers.constants.AddressZero, account1.address, liquidity); // (※3)
                /* (※3)event Transfer(address indexed from, address indexed to, uint value) ←　第三引数がuint(整数)。
                   number型でなくBigNumber型にしとけば少数の可能性を排除できる...ってことかな?(BigNumber型は小数部分が切り捨てられる)。
                   余談だが、javaScriptでの小数同士の計算が正確じゃない事情ってなんだ...。
                */ 
        });

        it("revert by deadline", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

            const deadline = Math.floor(Date.now() / 1000);

            const amountADesired = 100000;
            const amountBDesired = 100000;

            await tokenA.connect(account2).approve(router.address, amountADesired);
            await tokenB.connect(account2).approve(router.address, amountBDesired);
            
            await expect(router.connect(account2).addLiquidity(
                tokenA.address, tokenB.address, amountADesired, amountBDesired, 0, 0, account1.address, deadline
                )).to.be.revertedWith('uniswapV2StyleDexRouter: EXPIRED');
        });
    });

    describe("removeLiquidity", function() {
        it("test removeLiquidity", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

            const deadline = Math.floor(Date.now() / 1000) + 60;
            const liquidity = 40421;
            const totalSupply = await pool.totalSupply();
            const reserve0 = await pool.reserve0();
            const reserve1 = await pool.reserve1();
            const amount0Withdraw = Math.floor(reserve0 * liquidity / totalSupply);
            const amount1Withdraw = Math.floor(reserve1 * liquidity / totalSupply);
            const [amountAWithdraw, amountBWithdraw] = tokenA.address < tokenB.address ? [amount0Withdraw, amount1Withdraw] : [amount1Withdraw, amount0Withdraw];
            const [reserveA, reserveB] = tokenA.address < tokenB.address ? [reserve0, reserve1] : [reserve1, reserve0];

            await pool.connect(account1).approve(router.address, liquidity);
            await expect(router.connect(account1).removeLiquidity(tokenA.address, tokenB.address, liquidity, 0, 0, account2.address, deadline))
                .to.emit(pool, 'Transfer')
                .withArgs(account1.address, pool.address, liquidity)
                .to.emit(pool, 'Burn')
                .withArgs(router.address, amount0Withdraw, amount1Withdraw, account2.address);

            expect(await tokenA.balanceOf(account2.address)).to.eq(400000 + amountAWithdraw);
            expect(await tokenB.balanceOf(account2.address)).to.eq(500000 + amountBWithdraw);
            expect(await tokenA.balanceOf(pool.address)).to.eq(reserveA - amountAWithdraw);
            expect(await tokenB.balanceOf(pool.address)).to.eq(reserveB - amountBWithdraw);

            expect(await pool.balanceOf(owner.address)).to.eq(0);
            expect(await pool.balanceOf(account1.address)).to.eq(100000);
            expect(await pool.balanceOf(account2.address)).to.eq(0);
            expect(await pool.balanceOf(pool.address)).to.eq(0);
        });

        it("revert by amountMin", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

            const deadline = Math.floor(Date.now() / 1000) + 60;
            const amountAMin = 10000;
            const amountBMin = 10000;
            const liquidity = 10000;

            await pool.connect(account1).approve(router.address, liquidity);
            await expect(router.connect(account1).removeLiquidity(
                tokenA.address, tokenB.address, liquidity, amountAMin, amountBMin, account2.address, deadline
                )).to.be.revertedWith('uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
            /*
             - amountAWithdraw: 100000(reserveA) * 10000(liquidity) / 141421(totalSupply) = 7,071
             - amountBWithdraw: 200000(reserveB) * 10000(liquidity) / 141421(totalSupply) = 14,142
            */
        });

        it("revert by invalid token pairs", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);
            
            const deadline = Math.floor(Date.now() / 1000) + 60;
            const liquidity = 40421;

            await pool.connect(account1).approve(router.address, liquidity);
            await expect(router.connect(account1).removeLiquidity(owner.address, tokenB.address, liquidity, 0, 0, account2.address, deadline))
                .to.be.revertedWith('uniswapV2StyleDexRouter: POOL_DOES_NOT_EXIST');
        });
    });

    describe("swapTokenPair", function() {
        it("test swapTokenPair", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);
            
            const deadline = Math.floor(Date.now() / 1000) + 60;
            const reserveA = await tokenA.balanceOf(pool.address);
            const reserveB = await tokenB.balanceOf(pool.address);
            const amountIn = 100000;
            const amountOut = await router.getAmountOut(amountIn, reserveA, reserveB);
            const [amount0In, amount1In] = tokenA.address < tokenB.address ? [amountIn, 0] : [0, amountIn];
            const [amount0Out, amount1Out] = tokenA.address < tokenB.address ? [0, amountOut] : [amountOut, 0];

            await tokenA.connect(account2).approve(router.address, amountIn);
            await expect(router.connect(account2).swapTokenPair(tokenA.address, tokenB.address, amountIn, 0, account2.address, deadline))
                .to.emit(pool, 'Swap')
                .withArgs(router.address, amount0In, amount1In, amount0Out, amount1Out, account2.address);
            
            expect(await tokenA.balanceOf(pool.address)).to.eq(reserveA.add(amountIn));
            expect(await tokenB.balanceOf(account2.address)).to.eq(amountOut.add(500000));
        });

        it("revert by amountOutMin", async function() {
            const { owner, account1, account2, tokenA, tokenB, factory, pool, router } = await loadFixture(step2Fixture);

            const deadline = Math.floor(Date.now() / 1000) + 60;
            // const reserveA = await tokenA.balanceOf(pool.address);
            // const reserveB = await tokenB.balanceOf(pool.address);
            const amountIn = 10000;
            const amountOutMin = 30000;
            //amountOutは 18,132 になる。

            await tokenA.connect(account2).approve(router.address, amountIn);
            await expect(router.connect(account2).swapTokenPair(tokenA.address, tokenB.address, amountIn, amountOutMin, account2.address, deadline))
                .to.be.revertedWith('uniswapV2StyleDexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        });
    });
})