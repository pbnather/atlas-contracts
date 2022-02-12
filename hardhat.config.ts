import { HardhatUserConfig } from "hardhat/types";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-tracer";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-etherscan";
import { web3 } from "@defi.org/web3-candies";
import "hardhat-contract-sizer";
import { task } from "hardhat/config";
import { deploy } from "@defi.org/web3-candies/dist/hardhat/deploy";

function configFile() {
    return require("./.config.json");
}

task("deploy-magic-buyer").setAction(async () => {
    web3().eth.transactionPollingTimeout = 86400; // Day

    const contractAddress: string = await deploy("MagicMarketplaceBuyer", [],
        170924192, 0, false, 6);

    console.log("Finished!", contractAddress);
});

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.8.9",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1,
                    },
                },
            }
        ],
    },
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: {
                blockNumber: 5746555,
                url: "https://arb-mainnet.g.alchemy.com/v2/" + configFile().alchemyKey,
            },
        },
        eth: {
            chainId: 1,
            url: "https://eth-mainnet.alchemyapi.io/v2/" + configFile().alchemyKey,
        },
        rinkeby: {
            chainId: 4,
            url: "https://eth-rinkeby.alchemyapi.io/v2/" + configFile().alchemyKey,
        },
        arb: {
            chainId: 42161,
            url: `https://speedy-nodes-nyc.moralis.io/${configFile().moralisKey}/arbitrum/mainnet`,
        }
    },
    typechain: {
        outDir: "typechain-hardhat",
        target: "web3-v1",
    },
    mocha: {
        timeout: 1_000_000,
        retries: 0,
        bail: false,
    },
    gasReporter: {
        currency: "USD",
        coinmarketcap: configFile().coinmarketcapKey,
        showTimeSpent: true,
    },
    etherscan: {
        apiKey: {
            mainnet: configFile().etherscanKey,
            bsc: configFile().bscscanKey
        }
    },
    contractSizer: {
        runOnCompile: true
    }
};
export default config;
