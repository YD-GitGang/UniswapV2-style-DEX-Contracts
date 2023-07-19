import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { ContractFactory, Contract } from "ethers";

describe('Math', function() {
    async function deployMathFixture() {
        const Math: ContractFactory = await ethers.getContractFactory("MathTest");
        const math: Contract = await Math.deploy();
        await math.deployed();
        return { math }
    }

    it('min', async function () {
        const { math } = await loadFixture(deployMathFixture);

        expect(await math.min(0, 1)).to.eq(0);
        expect(await math.min(2, 1)).to.eq(1);
        expect(await math.min(2, 2)).to.eq(2);
    })

    it('sqrt', async function () {
        const { math } = await loadFixture(deployMathFixture);

        const nList = [1, 2, 3, 4, 5, 10, 99, 100, 1234, 5678, 999999];
        for (let n of nList) {
            expect(await math.sqrt(n)).to.eq(Math.floor(Math.sqrt(n))); //バビロニア法で計算される平方根は二乗してy以下になる最大の整数
        }
    })
})