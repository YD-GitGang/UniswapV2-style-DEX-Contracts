import { ethers, BigNumber } from "ethers";

export function getCreate2Address(factoryAddress: string, [tokenA, tokenB]: [string, string], bytecode: string): string {
    const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA]
    const create2Inputs = [
        '0xff',
        factoryAddress,
        ethers.utils.keccak256(ethers.utils.solidityPack(['address', 'address'], [token0, token1])),
        ethers.utils.keccak256(bytecode)
    ]
    const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`
    return ethers.utils.getAddress(`0x${ethers.utils.keccak256(sanitizedInputs).slice(-40)}`)
}

export function getAmountOut (amountIn: BigNumber | number, reserveIn: BigNumber | number, reserveOut: BigNumber | number): BigNumber{
    const amountInWithFee: BigNumber = BigNumber.from(amountIn).mul(997)
    const numerator: BigNumber = amountInWithFee.mul(reserveOut)
    const denominator: BigNumber = (BigNumber.from(reserveIn).mul(1000)).add(amountInWithFee)
    const amountOut = numerator.div(denominator)
    return amountOut
    /*
     - 定数積公式より　amountOut = {amountIn * 0.997 * reserveOut} / reserveIn{1 + ((amountIn * 0.997) / reserveIn)}
     - 分母分子に1000かけて小数消す。 
    */
}