const { ethers, upgrades } = require("hardhat");

async function main() {
  const usdt = "0x55d398326f99059fF775485246999027B3197955";
  const firtstAddr = "0xabb18E2e923Df026B430854d5E794F6bBe328142";
  const owner = "0x437F8cf6244D847DF61bC26d41d671AF8f371E47";
// main dao: 0xce9Bd4483f68fd63e1Ca5172f87FE77D4a03F51C
  

  const Dao = await ethers.getContractFactory("Dao");
  const dao = await upgrades.deployProxy(Dao, [usdt, firtstAddr,owner]);
  await dao.waitForDeployment();
  console.log("dao deployed to:", await dao.getAddress());
}

main();
