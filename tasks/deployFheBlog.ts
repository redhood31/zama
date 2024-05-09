import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

task("task:deployFheBlog").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers = await ethers.getSigners();
  const fheBlogFAC = await ethers.getContractFactory("FHE_BLOG");
  const fheBlog = await fheBlogFAC.connect(signers[0]).deploy();
  await fheBlog.waitForDeployment();
  const fheBlogAddress = await fheBlog.getAddress();
  console.log("FheBlog deployed to: ", fheBlogAddress);
  const fheBlogFactoryFAC = await ethers.getContractFactory("FHEBlogFactory");
  const fheBlogFactory = await fheBlogFactoryFAC.connect(signers[0]).deploy(fheBlogAddress);
  await fheBlogFactory.waitForDeployment();
  console.log("FheBlogFactory: ", await fheBlogFactory.getAddress());
});
