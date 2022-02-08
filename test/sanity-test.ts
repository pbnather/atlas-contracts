import { address1, helloWorld, prepareForTests } from "./test-base";
import { expect } from "chai";
import { block, bn, bn18, contract, erc20, erc20s, maxUint256, web3, zero } from "@defi.org/web3-candies";
import { TreasureMarketplace } from "../typechain-abi/treasureMarketplace";
import { impersonate, mineBlock, mineBlocks } from "@defi.org/web3-candies/dist/hardhat";

describe("----------  Hello world tests ---------- ", () => {
    beforeEach(async () => {
        await prepareForTests();
    });

    it("Simple test", async () => {
        expect(await helloWorld.methods.sayHello().call()).eq("hello world");
    });

    it("test", async () => {
        const treasureMarketPlace = contract<TreasureMarketplace>(require("../abi/treasureMarketplace.json"), "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee");
        console.log(await treasureMarketPlace.methods.owner().call());
        console.log(bn18("1.11").toString());
        expect(await erc20s.arb.WETH().methods.allowance(address1, "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee").call()).bignumber.eq(zero);
        await erc20s.arb.WETH().methods.approve("0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee", maxUint256).send({ from: address1 });
        expect(await erc20s.arb.WETH().methods.allowance(address1, "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee").call()).bignumber.eq(maxUint256);
        console.log((await web3().eth.getBlock(await web3().eth.getBlockNumber())).timestamp);
        await mineBlock(365 * 24 * 60 * 60);
        console.log((await web3().eth.getBlock(await web3().eth.getBlockNumber())).timestamp);
        await impersonate("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a");
        await web3().eth.sendTransaction({ from: address1, to: "0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", value: bn18("10") });
        expect(await erc20s.arb.WETH().methods.allowance("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", address1).call()).bignumber.eq(zero);
        await erc20s.arb.WETH().methods.approve(address1, maxUint256).send({ from: "0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a" });
        expect(await erc20s.arb.WETH().methods.allowance("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", address1).call()).bignumber.eq(maxUint256);
    });

});
