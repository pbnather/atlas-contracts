import { account, BlockNumber, bn, contract, erc20, erc20s, useChaiBN } from "@defi.org/web3-candies";
import { deployArtifact, resetNetworkFork, tag } from "@defi.org/web3-candies/dist/hardhat";
import { ERC20 } from "@defi.org/web3-candies/typechain-abi/ERC20";
import { AtlasMine } from "../typechain-abi/atlasMine";
import { AMagicStaking } from "../typechain-hardhat/AMagicStaking";
import { AMagicToken } from "../typechain-hardhat/AMagicToken";
import { CommunityMine } from "../typechain-hardhat/CommunityMine";

export let deployer: string;
export let treasury: string;
export let timelock: string;
export let splitter: string;
export let user1: string;
export let user2: string;
export let user3: string;
export let magic: ERC20;
export let aMagic: AMagicToken;
export let communityMine: CommunityMine;
export let atlasMine: AtlasMine;
export let aMagicStaking: AMagicStaking;

useChaiBN();

export async function prepareForTests(blockNumber?: number) {
    while (true) {
        try {
            return await doInitState(blockNumber);
        } catch (e) {
            console.error(e, "\ntrying again...");
        }
    }
}

async function doInitState(blockNumber?: number) {
    await resetNetworkFork(blockNumber);

    deployer = await account(0);
    treasury = await account(1);
    timelock = await account(2);
    splitter = await account(3);
    user1 = await account(4);
    user2 = await account(5);
    user3 = await account(6);



    tag(deployer, "deployer");
    tag(treasury, "treasury");
    tag(timelock, "timelock");
    tag(splitter, "splitter");
    tag(deployer, "user1");
    tag(deployer, "user2");
    tag(deployer, "user3");

    let magicAddress = "0x539bde0d7dbd336b79148aa742883198bbf60342";
    let atlasMineAddress = "0xA0A89db1C899c49F98E6326b764BAFcf167fC2CE";

    magic = erc20("magic", magicAddress);
    atlasMine = contract<AtlasMine>(require("../abi/atlasMine.json"), atlasMineAddress);
    aMagic = await deployArtifact<AMagicToken>("AMagicToken", { from: timelock }, []);
    communityMine = await deployArtifact<CommunityMine>("CommunityMine", { from: timelock }, []);
    aMagicStaking = await deployArtifact<AMagicStaking>(
        "AMagicStaking",
        { from: timelock },
        [magic.options.address, communityMine.options.address]);

    await communityMine.methods.initialize(
        erc20s.arb.WETH().address,
        magic.options.address,
        aMagic.options.address,
        atlasMine.options.address,
        aMagicStaking.options.address,
        treasury,
        splitter,
        bn("9000"),
        bn("10000"),
        bn("4")
    ).send({ from: timelock });

    tag(magic.options.address, "Magic Token");
    tag(aMagic.options.address, "aMagic Token");
    tag(communityMine.options.address, "Community Mine");
    tag(aMagicStaking.options.address, "aMagic Staking");
    tag(atlasMine.options.address, "Atlas Mine");
}
