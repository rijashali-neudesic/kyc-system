import { ethers } from "hardhat";

async function main() {
  deployKycSystem();
}

async function deployKycSystem () {
  const KycSystem = await ethers.getContractFactory('KycSystem');
  const kycSystem = await KycSystem.deploy();
  await kycSystem.deployed();

  console.log('KycSystem deployed @: ' + kycSystem.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
