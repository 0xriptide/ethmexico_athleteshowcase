// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const host = "0x3E14dC1b13c488a8d5D310918780c983bD5982E7";

  const aNFT = await hre.ethers.getContractFactory("AthleteNFT");
  const anft = await aNFT.deploy();

  await anft.deployed();

  const AthleteFunder = await ethers.getContractFactory("AthleteFunder");
  const af = await AthleteFunder.deploy(anft.address, host);

  await af.deployed();

  console.log(
    `good to go`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
