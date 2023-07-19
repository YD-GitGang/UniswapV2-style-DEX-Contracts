import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import uniswapV2StyleDexPool from "../artifacts/contracts/uniswapV2StyleDexPool.sol/uniswapV2StyleDexPool.json";

const MINIMUM_LIQUIDITY = 10**3;

describe("uniswapV2StyleDexPool test", function() {
    async function deployPoolFixture() {
        //accounts-----
        const [account0, account1 , account2] = await ethers.getSigners();

        //tokens-----
        const Token = await ethers.getContractFactory("TokenTest");
        const tokenA = await Token.deploy("tokenA", "A", 18, 1000000);
        const tokenB = await Token.deploy("tokenB", "B", 18, 1000000);
        //1つ下でデプロイしたtokenのアドレス使うんだけど、書き込まれるの待たなくてもアドレスはゲットできるからdeployed不要?
        const [token0, token1] = tokenA.address < tokenB.address ? [tokenA, tokenB] : [tokenB, tokenA];

        //Dex-----
        const Factory = await ethers.getContractFactory("uniswapV2StyleDexFactory");
        const factory = await Factory.deploy();
        await factory.deployed();
        await factory.createPool(token0.address, token1.address);
        //1つ下でawaitしてるからwait()不要?
        const poolAddress = await factory.getPool(token0.address, token1.address);
        const pool = new ethers.Contract(poolAddress, uniswapV2StyleDexPool.abi, ethers.provider);
        return { account0, account1, account2, factory, pool, token0, token1 };
    }

    describe("state variables", function() {
        it("factory address", async function() {
            const { factory, pool } = await loadFixture(deployPoolFixture);
            expect(await pool.factory()).to.eq(factory.address);
        });

        it("token address", async function() {
            const { pool, token0, token1 } = await loadFixture(deployPoolFixture);
            expect(await pool.token0()).to.eq(token0.address);
            expect(await pool.token1()).to.eq(token1.address);
        });
    });

    describe("initialize", function() {
        it("not callable by user accounts", async function() {
            const { account0, account1, account2, pool, token0, token1 } = await loadFixture(deployPoolFixture);
            await expect(pool.connect(account0).initialize(token0.address, token1.address)).to.be.revertedWith("uniswapV2StyleDexPool: INITIALIZATION_FORBIDDEN");
            await expect(pool.connect(account1).initialize(token0.address, token1.address)).to.be.revertedWith("uniswapV2StyleDexPool: INITIALIZATION_FORBIDDEN");
            await expect(pool.connect(account2).initialize(token0.address, token1.address)).to.be.revertedWith("uniswapV2StyleDexPool: INITIALIZATION_FORBIDDEN");
        })
    })

    describe("mint", function() {
        it("token balances", async function() {
            const { account0, token0, token1 } = await loadFixture(deployPoolFixture);
            expect(await token0.balanceOf(account0.address)).to.eq(1000000);
            expect(await token1.balanceOf(account0.address)).to.eq(1000000);
        });

        it("mint liquidity to an account1 by account2", async function() {
            const { account0, account1, account2, pool, token0, token1 } = await loadFixture(deployPoolFixture);
            const token0Amount = 40000;
            const token1Amount = 90000;
            const liquidity = Math.sqrt(token0Amount * token1Amount);
            await token0.transfer(pool.address, token0Amount);
            await token1.transfer(pool.address, token1Amount);
            await expect(pool.connect(account2).mint(account1.address))
                .to.emit(pool, 'Transfer')
                .withArgs(ethers.constants.AddressZero, account1.address, liquidity - MINIMUM_LIQUIDITY)
                .to.emit(pool, 'Mint')
                .withArgs(account2.address, token0Amount, token1Amount);

            expect(await pool.balanceOf(account1.address)).to.eq(liquidity - MINIMUM_LIQUIDITY);
            expect(await token0.balanceOf(pool.address)).to.eq(token0Amount);
            expect(await token1.balanceOf(pool.address)).to.eq(token1Amount);
        });

        it("mint reverted for insufficient initial deposit", async function() {
            const {account0, account1, account2, pool, token0, token1} = await loadFixture(deployPoolFixture);
            const token0Amount = 999;
            const token1Amount = 999;
            await token0.transfer(pool.address, token0Amount);
            await token1.transfer(pool.address, token1Amount);
            await expect(pool.connect(account2).mint(account1.address)).to.be.revertedWith('uniswapV2StyleDexPool: BELOW_MINIMUM_LIQUIDITY');
        });

        it("second mint reverted for insufficient deposit", async function() {
            const { account0, account1, account2, pool, token0, token1 } = await loadFixture(deployPoolFixture);
            const token0Amount = 40000;
            const token1Amount = 90000;
            const liquidity = Math.sqrt(token0Amount * token1Amount);
            await token0.transfer(pool.address, token0Amount);
            await token1.transfer(pool.address, token1Amount);
            await pool.connect(account2).mint(account1.address);
            await expect(pool.connect(account2).mint(account1.address)).to.be.revertedWith('uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY_MINTED');
        });
    })
})