import hre from "hardhat";

import { LUBE, LUBE__factory } from "../types";

async function main(): Promise<void> {
  const name: string = "lube-test";
  const symbol: string = "LUBE";

  const signers = await hre.ethers.getSigners();
  // ignore address 0
  const taxAddress = signers[1];
  const poolAddress = signers[2];

  const Lube: LUBE__factory = await hre.ethers.getContractFactory("LUBE");
  const lube: LUBE = await Lube.deploy(name, symbol, taxAddress);

  await lube.setPoolAddress(poolAddress);
}

// We recommend this pattern to be able to use async/await everywhere and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
