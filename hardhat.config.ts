import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true, // Default: false
            runs: 200, // Default: 200,
          },
          viaIR: true,
        },
      },
    ],
  },
  networks: {
    hardhat: {
    },
    bsctest: {
      url: "https://data-seed-prebsc-2-s1.bnbchain.org:8545",
      chainId: 97,
      accounts: [""]
    },
    bsc: {
      url: "https://bsc-dataseed3.ninicoin.io/",
      chainId: 56,
      accounts: [""]
    }
  }
};

export default config;
