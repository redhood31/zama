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
const generateJwt = async(contract, relayer_signer, relayer_instance, caller_signer, relayer_id, nft_token) => {
  // 
  const current_nonce = await contract.latest_nonce(caller_signer.address);
  const signature = await generateSignature(relayer_id, current_nonce, caller_signer)
  

  const contractAddress = await contract.getAddress();
  const token = relayer_instance.getPublicKey(contractAddress)!;


  const relayerContract = await contract.connect(relayer_signer)


  const tx1 = await relayerContract.generateJwt(nft_token, relayer_id, caller_signer.address, current_nonce, signature, token.publicKey) // need token.signature?

  console.log(" YEY RESULT IS " , tx1)

  return {
    p : [
      relayer_instance.decrypt(contractAddress, tx1.p[0]),
      relayer_instance.decrypt(contractAddress, tx1.p[1])
    ]
  }


}
const getReward = async(contract, relayer_signer)=>{
  let init = await contract.reward(relayer_signer.address);
  return init;
}
// await claimReward(alice_contract, this.signers.bob, this.signers.alice, 3, signature, current_nonce);

const claimReward = async(contract, relayer_signer, caller,relayer_id, signature, _nonce)=>{

    const relayerContract = await contract.connect(relayer_signer);

    await relayerContract.claimReward(relayer_id, caller, _nonce, signature);

}



const getSampleAliceContract = async(alice_instance, signer_alice, init_contract, signers)=>{
  const factory_contract: FHEBlogFactory = await deployFheBlogFactory(signer_alice, init_contract)

  const predicted_address = await factory_contract.getBlogAddress('0xf172873c63909462ac4de545471fd3ad3e9eeadeec4608b92d16ce6b500704cc');
  const instances = await createInstances(predicted_address, ethers, signers);
  let cid = [
    new Uint8Array([1]),
    new Uint8Array([2]),
    new Uint8Array([3])
  ]
  let pi = [[17 , 12], [14, 13], [19 , 20]];
  
  let encryptedPi = [];


  for(let pkey of pi){
    encryptedPi.push(
      [
        alice_instance.encrypt64(pkey[0]),
        alice_instance.encrypt64(pkey[1])
      ]
    )          
  }
  // console.log(instances.bob.getPublicKey(predicted_address));
  let BlogStorage = {
    cid: cid,
    p: encryptedPi,
    publicKey: [
      instances.bob.getPublicKey(predicted_address).publicKey,
      instances.bob.getPublicKey(predicted_address).publicKey,
      instances.bob.getPublicKey(predicted_address).publicKey
    ]
  }
  console.log("lol man " , BlogStorage)
  const txDeploy = await createTransaction(
    factory_contract["createBlog((bytes[],bytes[2][],bytes32[]),string,string,bytes32)"],
    BlogStorage,  
    'FHE_BLOG',
    'FHBL',
    "0xf172873c63909462ac4de545471fd3ad3e9eeadeec4608b92d16ce6b500704cc",
  );
  await txDeploy.wait();
  console.log("-------AFTER DEPLOY YYYYY")
 
 
  console.log("GET TOKEN SIGNATURE ")

  const alice_contract_adress = await factory_contract.blogs(0);
  const alice_contract : FHE_BLOG = FHE_BLOG__factory.connect(alice_contract_adress).connect(signer_alice);
  
  return alice_contract;
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
      });

      it("Checks the signatures", async function(){
        
         console.log(" hey alisa " , this.signers.alice)
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

      it("get nft", async function() {

        const alice_contract = await getSampleAliceContract(this.instances.alice, this.signers.alice, this.nft_contract, this.signers)
        const alice_contract_adress = await alice_contract.getAddress();
        this.instances = await createInstances(alice_contract_adress, ethers, this.signers);
        

        const nft_token = await alice_contract.s_tokenCounter();
        await alice_contract.mintNft();
        

        assert.equal(this.signers.alice.address == await alice_contract.ownerOf(nft_token), true)
  
      });
      it("get jwt", async function(){

        const alice_contract = await getSampleAliceContract(this.instances.alice, this.signers.alice, this.nft_contract, this.signers)
        const alice_contract_adress = await alice_contract.getAddress();
        this.instances = await createInstances(alice_contract_adress, ethers, this.signers);
        
        const nft_token = await alice_contract.s_tokenCounter();
        await alice_contract.mintNft();
        



        const blogStorage = await generateJwt(alice_contract, this.signers.bob, this.instances.bob, this.signers.alice, 0, nft_token);

        console.log("BLOG STORAGE IS " , blogStorage)

       
      })
      it("check reward", async function(){

        const alice_contract = await getSampleAliceContract(this.instances.alice, this.signers.alice, this.nft_contract, this.signers)
        const alice_contract_adress = await alice_contract.getAddress();
        this.instances = await createInstances(alice_contract_adress, ethers, this.signers);
        
        const nft_token = await alice_contract.s_tokenCounter();
        await alice_contract.mintNft();
        

        const current_nonce = await alice_contract.latest_nonce(this.signers.alice.address);
        const signature = await generateSignature(3, current_nonce, this.signers.alice);
        
        const blogStorage = await generateJwt(alice_contract, this.signers.bob, this.instances.bob, this.signers.alice, 0, nft_token);

        assert.equal(await getReward(alice_contract, this.signers.bob), 0);

        await claimReward(alice_contract, this.signers.bob, this.signers.alice, 3, signature, current_nonce);

        assert.equal(await getReward(alice_contract, this.signers.bob), 1);

        await claimReward(alice_contract, this.signers.bob, this.signers.alice, 3, signature, current_nonce);

        assert.equal(await getReward(alice_contract, this.signers.bob), 1);

        console.log("BLOG STORAGE IS " , blogStorage)

       
      })
    
 
  });