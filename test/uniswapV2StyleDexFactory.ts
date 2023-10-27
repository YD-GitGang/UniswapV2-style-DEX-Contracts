import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { ContractFactory, Contract } from "ethers";
import { getCreate2Address } from "./lib/utilities";
import uniswapV2StyleDexPool from '../artifacts/contracts/uniswapV2StyleDexPool.sol/uniswapV2StyleDexPool.json';

const TEST_ADDRESSES: [string, string] = [
    '0x1230000000000000000000000000000000000000',
    '0x3450000000000000000000000000000000000000'
]

describe("uniswapV2StyleDexFactory", function () {
    async function deployFactoryFixture() {
        const Factory: ContractFactory = await ethers.getContractFactory("uniswapV2StyleDexFactory");  //(※1)
        const factory: Contract = await Factory.deploy();  //(※2)
        await factory.deployed();
        return { factory }
    }
    /*
     - (※1)
     - 純粋にethersでデプロイではなくhardhat使ってデプロイする時は
     - ContractFactory(abi, bytecode, signer)じゃなくてgetContractFactory("コントラクト名")で済む。本番ではなくhardhatネットワーク使用時の
     - getContractFactory("コントラクト名")の中身はコントラクトをコンパイルしたartifactsにあるabiとbytecodeと、hardhatネットワークにアクセス
     - するためのプロバイダー(多分 ethers.provider )とかをかき集めたもの、多分。hardhatネットワークだから秘密鍵はハショれる、多分。
     - getContractFactoryがabiとか色々かき集めるから待ってくれということでawait、多分。
     - 一方hardhat使わない素のethersの書き方は new ethers.ContractFactory(abi, bytecode, signer)。abiとかを直で渡してコントラクトのインスタ
     - ンスをつくるからnew、多分。
     - 
     - (※2)
     - await Factory.deploy()の返値は、
     - 本番ネットワークで関数呼び出しする時に使う、コントラクトにアクセスするためのオブジェクト new ethers.Contract(address, abi, provider) に
     - 相当する物なんだろう、きっと。
    */

    it("get no pool address before creation", async function () {
        const { factory } = await loadFixture(deployFactoryFixture);
        expect(await factory.getPool(...TEST_ADDRESSES)).to.eq(ethers.constants.AddressZero);
    })

    it("get pool address after creation", async function() {
        const { factory } = await loadFixture(deployFactoryFixture);
        const tx = await factory.createPool(...TEST_ADDRESSES);
        const receipt = await tx.wait();
        const event = factory.interface.parseLog(receipt.logs[0]);
        expect(event.name).to.eq('PoolCreated');
        const poolAddress: string = event.args[2];
        expect(await factory.getPool(TEST_ADDRESSES[0], TEST_ADDRESSES[1])).to.eq(poolAddress);
        expect(await factory.getPool(TEST_ADDRESSES[1], TEST_ADDRESSES[0])).to.eq(poolAddress);
    })
    
    it("pool created at expected address", async function() {
        const { factory } = await loadFixture(deployFactoryFixture);
        const bytecode: string = uniswapV2StyleDexPool.bytecode;
        const [address0, address1] = TEST_ADDRESSES[0] < TEST_ADDRESSES[1] ? TEST_ADDRESSES : [TEST_ADDRESSES[1], TEST_ADDRESSES[0]];
        const creat2Address = getCreate2Address(factory.address, [address0, address1], bytecode);

        await expect(factory.createPool(...TEST_ADDRESSES))
        .to.emit(factory, 'PoolCreated')
        .withArgs(address0, address1, creat2Address); //アドレスをソートした恩恵は多分ここでうける。
    });
})