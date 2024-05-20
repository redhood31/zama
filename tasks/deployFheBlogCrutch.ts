import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

task("task:deployFheBlogCrutch").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers = await ethers.getSigners();
  const fheBlogFAC = await ethers.getContractFactory("FHE_BLOGCrutch");
  const fheBlog = await fheBlogFAC.connect(signers[0]).deploy();
  await fheBlog.waitForDeployment();
  const fheBlogAddress = await fheBlog.getAddress();
  console.log("FheBlog deployed to: ", fheBlogAddress);
  const fheBlogFactoryFAC = await ethers.getContractFactory("FHEBlogFactoryCrutch");
  const fheBlogFactory = await fheBlogFactoryFAC.connect(signers[0]).deploy(fheBlogAddress);
  await fheBlogFactory.waitForDeployment();
  console.log("FheBlogFactory deployed to: ", await fheBlogFactory.getAddress());
  console.log("signer is " , await signers[0].getAddress());
});
