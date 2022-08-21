const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Athlete", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAthlete() {

    // Contracts are deployed using the first signer/account by default
    const [owner] = await ethers.getSigners();

    const host = "0x3E14dC1b13c488a8d5D310918780c983bD5982E7";

    const AthleteNFT = await ethers.getContractFactory("AthleteNFT");
    const aNFT = await AthleteNFT.deploy();

    const AthleteFunder = await ethers.getContractFactory("AthleteFunder");
    const af = await AthleteFunder.deploy(aNFT.address, host);

    return { aNFT, af, owner };
  }

  describe("Deployment", function () {

    it("Should set the right owner", async function () {
      const { af, owner } = await loadFixture(deployAthlete);
      //expect(0).to.equal(0);
      expect(await af.owner()).to.equal(owner.address);
    });

    it("Should set the correct AthleteNFT contract address", async function () {
      const { aNFT, af } = await loadFixture(
        deployAthlete
      );

      expect(await af.athleteNFT()).to.equal(
        aNFT.address
      );
    });

  });
});
