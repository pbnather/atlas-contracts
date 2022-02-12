import { account, contract, erc20, useChaiBN } from "@defi.org/web3-candies";
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

    let magicAddress = "0x539bde0d7dbd336b79148aa742883198bbf60342";
    let atlasMineAddress = "0xA0A89db1C899c49F98E6326b764BAFcf167fC2CE";

    tag(deployer, "deployer");
    tag(treasury, "treasury");
    tag(timelock, "timelock");
    tag(splitter, "splitter");
    tag("0x539bde0d7dbd336b79148aa742883198bbf60342", "magicAddress");

    magic = erc20("magic", magicAddress);
    atlasMine = contract<AtlasMine>(require("../abi/atlasMine.json"), atlasMineAddress);
    aMagic = await deployArtifact<AMagicToken>("AMagicToken", { from: timelock }, []);
    communityMine = await deployArtifact<CommunityMine>("CommunityMine", { from: timelock }, []);
    aMagicStaking = await deployArtifact<AMagicStaking>(
        "AMagicStaking",
        { from: timelock },
        [magic.options.address, communityMine.options.address]);
}
