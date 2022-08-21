require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  networks: {
   hardhat: {
    chainId: 1,
    forking: {
     url: "https://polygon-mainnet.g.alchemy.com/v2/EIyAQldpnfMe3APBYNMjPLNZAzamQ8qR",
    },
   }
 },
  solidity: {
    compilers: [
      {
        version: "0.8.14",
      },
    ],
  },
};