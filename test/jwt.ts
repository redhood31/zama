import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { expect, assert} from "chai";
import { ethers } from "hardhat";

import { FHE_BLOG, FHEBlogFactory, FHE_BLOG__factory } from "../types";
import { createInstances } from "./instance";
import { getSigners, initSigners } from "./signers";
import { createTransaction } from "./utils";


const deploy2 = async (signer) => {
  
  const contractFactory = await ethers.getContractFactory("FHE_BLOG");
  const contract = await contractFactory.connect(signer).deploy(); // City of Zama's battle
  await contract.waitForDeployment();
  console.log("\nDEBUG INFO----------\n\n", await contract.getAddress())
  return contract;
}

const deployFheBlogFactory = async(signer, initial_contract) =>{
  

  const contractFactory = await ethers.getContractFactory("FHEBlogFactory");
  const contract = await contractFactory.connect(signer).deploy(await initial_contract.getAddress()); // City of Zama's battle
  await contract.waitForDeployment();
  console.log("\nDEBUG INFO----------\n\n", await contract.getAddress())
  return contract;
}

const generateSignature = async(relayer_id, nonce, signer) => {
    let signer_addr = signer.address;
    let abiencoder = new ethers.AbiCoder();
    let encoded = abiencoder.encode(["uint256", "uint256"], [relayer_id, nonce]);
    const hash = ethers.keccak256(encoded);
    const messageBytes = Buffer.from(hash.slice(2), 'hex');
    const signature = await signer.signMessage(messageBytes );
    return signature;
}
const generateJwt = async(contract, relayer_signer, relayer_instance, caller_signer, relayer_id) => {
  // 
  const current_nonce = await contract.nonce();
  const signature = await generateSignature(relayer_id, current_nonce, caller_signer)
  

  const contractAddress = await contract.getAddress();
  const token = relayer_instance.getPublicKey(contractAddress)!;


  const relayerContract = await contract.connect(relayer_signer)


  const tx1 = await relayerContract.generateJwt(relayer_id, caller_signer.address, current_nonce, signature, token.publicKey) // need token.signature?

  console.log(" YEY RESULT IS " , tx1)
  const cids = tx1.cid;

  console.log(" CID IS " , cids)


  const decryptedPis = [];

  for(let pid of tx1.p){
    decryptedPis.push([
      relayer_instance.decrypt(contractAddress, pid[0]),
      relayer_instance.decrypt(contractAddress, pid[1])
    ])
  }

  return {
    cid: cids,
    p : decryptedPis
  }


}

describe("FHE_BLOG_TESTS", function () {
    before(async function () {
      await initSigners();
      this.signers = await getSigners();
    });
    beforeEach(async function () {
        this.nft_contract = await deploy2(this.signers.alice)
        this.contractAddress = await this.nft_contract.getAddress();
        this.instances = await createInstances(this.contractAddress, ethers, this.signers);
      });
      it("Initializes the NFT Correctly.", async function () {

          const name = await this.nft_contract.name()
  
          const symbol = await this.nft_contract.symbol()
          const tokenCounter=await this.nft_contract.getTokenCounter()
          assert.equal(name, "")
          assert.equal(symbol, "")
          assert.equal(tokenCounter.toString(),"0")
      })

      it("Checks the signatures", async function(){

        let relayer_id = 3;
        let nonce = 0;
        let signer_addr = this.signers.alice.address;

        let abiencoder = new ethers.AbiCoder();
        let encoded = abiencoder.encode(["uint256", "uint256"], [relayer_id, nonce]);
        const hash = ethers.keccak256(encoded);
        const messageBytes = Buffer.from(hash.slice(2), 'hex');

        const signature = await this.signers.alice.signMessage(messageBytes );
        
        const result = await this.nft_contract.verifySignature(relayer_id , nonce, signer_addr, signature);
        const result1 = await this.nft_contract.verifySignature(nonce , relayer_id, signer_addr, signature);
        assert.equal(result, true);
        assert.equal(result1, false);

      });


      it("creating constructor", async function(){
        /// alice is the main actor here


        const factory_contract: FHEBlogFactory = await deployFheBlogFactory(this.signers.alice, this.nft_contract)
        this.factory_contract = factory_contract;

        let cid = [1, 2, 3]
        let pi = [[17 , 12], [14, 13], [19 , 20]];
        
        let encryptedPi = [];


        for(let pkey of pi){
          encryptedPi.push(
            [
              this.instances.alice.encrypt64(pkey[0]),
              this.instances.alice.encrypt64(pkey[1])
            ]
          )          
        }
        let BlogStorage = {
          cid: cid,
          p: encryptedPi
        }
        console.log("lol man " , BlogStorage)
        const txDeploy = await createTransaction(
          factory_contract.createBlog,
          BlogStorage,  
          'FHE_BLOG',
          'FHBL',
          "0xf172873c63909462ac4de545471fd3ad3e9eeadeec4608b92d16ce6b500704cc"
        );
        await txDeploy.wait();
        console.log("-------AFTER DEPLOY YYYYY")
       
       
        console.log("GET TOKEN SIGNATURE ")

        let alice_contract_adress = await factory_contract.userLastContract(this.signers.alice.address);
        const alice_contract : FHE_BLOG = FHE_BLOG__factory.connect(alice_contract_adress).connect(this.signers.alice);


        alice_contract_adress = await alice_contract.getAddress();
        this.instances = await createInstances(alice_contract_adress, ethers, this.signers);
        


        const blogStorage = await generateJwt(alice_contract, this.signers.bob, this.instances.bob, this.signers.alice, 3);

        console.log("BLOG STORAGE IS " , blogStorage)

       
      })

    // describe("Constructor", () => {
    // })
 
  });