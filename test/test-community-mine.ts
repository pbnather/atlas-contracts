import { aMagic, aMagicStaking, atlasMine, communityMine, magic, prepareForTests, splitter, timelock, treasury, user1 } from "./test-base";
import { expect } from "chai";
import { block, bn, bn18, contract, contracts, erc20, erc20s, ether, expectRevert, maxUint256, web3, zero, zeroAddress } from "@defi.org/web3-candies";
import { TreasureMarketplace } from "../typechain-abi/treasureMarketplace";
import { deployArtifact, hre, impersonate, mineBlock, mineBlocks } from "@defi.org/web3-candies/dist/hardhat";
import { AtlasMine } from "../typechain-abi/atlasMine";
import { LegionERC721 } from "../typechain-abi/LegionERC721";
import { CommunityMine } from "../typechain-hardhat/CommunityMine";

describe("CommunityMine", () => {
    beforeEach(async () => {
        await prepareForTests();
    });

    it("should initialize properly", async () => {
        const miningPercent = bn("9000");
        const depositThreshold = bn("10000");
        const lock = bn("4");

        const newCommunityMine = await deployArtifact<CommunityMine>("CommunityMine", { from: timelock }, []);

        await newCommunityMine.methods.initialize(
            erc20s.arb.WETH().address,
            magic.options.address,
            aMagic.options.address,
            atlasMine.options.address,
            aMagicStaking.options.address,
            treasury,
            splitter,
            miningPercent,
            depositThreshold,
            lock
        ).send({ from: timelock });

        expect(await communityMine.methods.weth().call()).eq(erc20s.arb.WETH().address);
        expect(await communityMine.methods.magic().call()).eq(magic.options.address);
        expect(await communityMine.methods.aMagic().call()).eq(aMagic.options.address);
        expect(await communityMine.methods.atlasMine().call()).eq(atlasMine.options.address);
        expect(await communityMine.methods.aMagicStaking().call()).eq(aMagicStaking.options.address);
        expect(await communityMine.methods.treasury().call()).eq(treasury);
        expect(await communityMine.methods.rewardSplitter().call()).eq(splitter);
        expect(await communityMine.methods.treasure().call()).eq(await atlasMine.methods.treasure().call());
        expect(await communityMine.methods.legion().call()).eq(await atlasMine.methods.legion().call());
        expect(await communityMine.methods.miningPercent().call()).bignumber.equals(miningPercent);
        expect(await communityMine.methods.depositThreshold().call()).bignumber.equals(depositThreshold);
        expect(await communityMine.methods.lock().call()).bignumber.equals(lock);
        expect(await communityMine.methods.idleMagic().call()).bignumber.equals(zero);
    });

    it("can only be initialized once", async () => {
        const miningPercent = bn("9000");
        const depositThreshold = bn("10000");
        const lock = bn("4");

        expectRevert(async () => {
            await communityMine.methods.initialize(
                erc20s.arb.WETH().address,
                magic.options.address,
                aMagic.options.address,
                atlasMine.options.address,
                aMagicStaking.options.address,
                treasury,
                splitter,
                miningPercent,
                depositThreshold,
                lock
            ).send({ from: timelock });
        }, "Initializable: contract is already initialized")
    });

    it("Splitter should be set properly", async () => {
        expect(await communityMine.methods.rewardSplitter().call()).eq(splitter);
        await communityMine.methods.setRewardSplitter(user1).send({ from: timelock });
        expect(await communityMine.methods.rewardSplitter().call()).eq(user1);
    });

    it("Only owner can set splitter", async () => {
        expectRevert(async () => {
            await communityMine.methods.setRewardSplitter(splitter).send({ from: user1 });
        }, "Ownable: caller is not the owner");
    });

    it("Splitter cannot be set to address zero", async () => {
        expectRevert(async () => {
            await communityMine.methods.setRewardSplitter(zeroAddress).send({ from: timelock });
        }, "Cannot set address zero");
    });

    it("Mining percent should be set properly", async () => {
        const miningPercent = bn("9000");
        const newMiningPercent = bn("5000");
        expect(await communityMine.methods.miningPercent().call()).bignumber.equals(miningPercent);
        await communityMine.methods.setMiningPercent(newMiningPercent).send({ from: timelock });
        expect(await communityMine.methods.miningPercent().call()).bignumber.equals(newMiningPercent);
    });

    it("Only owner can set mining percent", async () => {
        expectRevert(async () => {
            await communityMine.methods.setMiningPercent(bn("5000")).send({ from: user1 });
        }, "Ownable: caller is not the owner");
    });

    it("Mining percent cannot be set over 100%", async () => {
        expectRevert(async () => {
            await communityMine.methods.setMiningPercent(bn("12000")).send({ from: timelock });
        }, "Value greater than 10000, 100%");
    });

    it("Lock time should be set properly", async () => {
        const lock = bn("4");
        const newLock = bn("1");
        expect(await communityMine.methods.lock().call()).bignumber.equals(lock);
        await communityMine.methods.changeLockTime(newLock).send({ from: timelock });
        expect(await communityMine.methods.lock().call()).bignumber.equals(newLock);
    });

    it("Only owner can set lock time", async () => {
        expectRevert(async () => {
            await communityMine.methods.setMiningPercent(bn("1")).send({ from: user1 });
        }, "Ownable: caller is not the owner");
    });

    it("Lock time cannot be set to unexisting lock", async () => {
        expectRevert(async () => {
            await communityMine.methods.changeLockTime(bn("1337")).send({ from: timelock });
        }, "value out-of-bounds");
    });

    it("Deposit threshold should be set properly", async () => {
        const depositThreshold = bn("10000");
        const newDepositThreshold = bn("5000");
        expect(await communityMine.methods.depositThreshold().call()).bignumber.equals(depositThreshold);
        await communityMine.methods.changeDepositThreshold(newDepositThreshold).send({ from: timelock });
        expect(await communityMine.methods.depositThreshold().call()).bignumber.equals(newDepositThreshold);
    });

    it("Only owner can set deposit threshold", async () => {
        expectRevert(async () => {
            await communityMine.methods.changeDepositThreshold(bn("5000")).send({ from: user1 });
        }, "Ownable: caller is not the owner");
    });



    // it("test", async () => {
    //     const treasureMarketPlace = contract<TreasureMarketplace>(require("../abi/treasureMarketplace.json"), "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee");
    //     console.log(await treasureMarketPlace.methods.owner().call());
    //     console.log(bn18("1.11").toString());
    //     expect(await erc20s.arb.WETH().methods.allowance(address1, "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee").call()).bignumber.eq(zero);
    //     await erc20s.arb.WETH().methods.approve("0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee", maxUint256).send({ from: address1 });
    //     expect(await erc20s.arb.WETH().methods.allowance(address1, "0x2E3b85F85628301a0Bce300Dee3A6B04195A15Ee").call()).bignumber.eq(maxUint256);
    //     console.log((await web3().eth.getBlock(await web3().eth.getBlockNumber())).timestamp);
    //     await mineBlock(365 * 24 * 60 * 60);
    //     console.log((await web3().eth.getBlock(await web3().eth.getBlockNumber())).timestamp);
    //     await impersonate("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a");
    //     await web3().eth.sendTransaction({ from: address1, to: "0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", value: bn18("10") });
    //     expect(await erc20s.arb.WETH().methods.allowance("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", address1).call()).bignumber.eq(zero);
    //     await erc20s.arb.WETH().methods.approve(address1, maxUint256).send({ from: "0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a" });
    //     expect(await erc20s.arb.WETH().methods.allowance("0xC643Fc22FCde1d2C75bC19BE5b992c6E52f6724a", address1).call()).bignumber.eq(maxUint256);
    // });

    // it("calculate max deposits", async () => {
    //     const legionHolder = "0x702D6DeF95d59E31ebA8420372821c2E49F2D607";
    //     const magicWhale = "0x2f14a4abc940049de389973c8d4ad022712dafc6";
    //     const whale = "0xf977814e90da44bfa03b6295a0616a897441acec";
    //     const atlasMineAddress = "0xA0A89db1C899c49F98E6326b764BAFcf167fC2CE";
    //     const atlasMine = contract<AtlasMine>(require("../abi/atlasMine.json"), atlasMineAddress);
    //     await impersonate(magicWhale);
    //     await impersonate(legionHolder);
    //     await impersonate(whale);
    //     const magic = erc20("magic", "0x539bde0d7dbd336b79148aa742883198bbf60342");
    //     console.log(await magic.methods.balanceOf(magicWhale).call());
    //     console.log(await magic.methods.balanceOf(atlasMineAddress).call());
    //     await communityMine.methods.initialize(erc20s.arb.WETH().address, magic.address, devWallet, atlasMineAddress, devWallet, devWallet, devWallet, bn("900")).send({ from: devWallet });
    //     console.log(await communityMine.methods.miningPercent().call());
    //     await web3().eth.sendTransaction({ from: whale, to: legionHolder, value: bn18("10000") });
    //     await magic.methods.transfer(legionHolder, bn18("700000")).send({ from: magicWhale });
    //     await magic.methods.approve(atlasMineAddress, bn18("700000")).send({ from: legionHolder });
    //     for (let i = 0; i < 135; i++) {
    //         await atlasMine.methods.deposit(bn18("4500"), bn("4")).send({ from: legionHolder });
    //     }

    //     const legions = contract<LegionERC721>(require("../abi/legionERC721.json"), "0xfE8c1ac365bA6780AEc5a985D989b327C27670A1");
    //     await legions.methods.setApprovalForAll(atlasMineAddress, true).send({ from: legionHolder });
    //     console.log(await legions.methods.balanceOf(legionHolder).call());
    //     // console.log(await legions.methods.ownerOf(bn("11120")).call());
    //     // await legions.methods.setApprovalForAll(address1, true).send({ from: legionHolder });
    //     // await legions.methods.safeTransferFrom(legionHolder, address1, 11120).send({ from: address1 });
    //     const tx = await atlasMine.methods.stakeLegion(2899).send({ from: legionHolder });
    //     console.log(tx["cumulativeGasUsed"], tx["gasUsed"]);
    //     const tx2 = await atlasMine.methods.stakeLegion(2898).send({ from: legionHolder });
    //     console.log(tx2["cumulativeGasUsed"], tx2["gasUsed"]);
    // });

});
