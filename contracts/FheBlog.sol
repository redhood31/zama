pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/Reencrypt.sol";
import "./utils/EncryptedErrors.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// onlyUser? onlyRelayer?

struct DecryptedBlog{
    bytes[2] p;
}

struct BlogStorage{
    bytes[] cid;
    bytes32[] publicKey;
}

contract FHE_BLOG is Initializable, ERC721Upgradeable {
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    uint256 public s_tokenCounter;

    euint64[2][] private p;
    
    BlogStorage private data;
    mapping(address => mapping(uint64 => bool)) internal rewarded;
    mapping(address => uint256) public reward;
    mapping(address => uint64) public latest_nonce;
    // function data()
    function initialize(
        BlogStorage calldata _data, bytes[2][] calldata _p, string calldata _nft_name, string calldata _nft_short_name
    ) external initializer{
         __ERC721_init(_nft_name, _nft_short_name);
        // data = _data;
        for (uint256 i = 0; i < _data.cid.length; i++) {
            data.cid.push(_data.cid[i]);
            euint64[2] memory cur_p;
            p.push(cur_p);
            p[i][0] = TFHE.asEuint64(_p[i][0]);
            p[i][1] = TFHE.asEuint64(_p[i][1]);
            data.publicKey.push(_data.publicKey[i]);
        }
        s_tokenCounter = 0;
    }

    constructor() {
        _disableInitializers();
    }
    function mintNft() public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;
    }
    function increaseNonce() public{
        latest_nonce[msg.sender] += 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return TOKEN_URI;
    } 

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function verifySignature(
        uint8 relayer_id,
        uint256 nonce,
        address signer,
        bytes memory signature
    ) public pure returns (bool) {

        bytes32 hashh = keccak256(abi.encode(bytes32(uint256(relayer_id)), 
                                                    bytes32(uint256(nonce)))
        );

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hashh);
        address recoveredSigner = ECDSA.recover(digest, signature);
        return signer == recoveredSigner;
    }

    function getCid(uint256 relayer_id) public view returns (bytes memory) {
        return data.cid[relayer_id];
    }

    function generateJwt(uint256 nft, uint8 relayer_id, address caller, uint256 _nonce, bytes memory signature) public view returns (DecryptedBlog memory) {
       
        assert(ownerOf(nft) == caller);
        assert(verifySignature(relayer_id, _nonce, caller, signature) == true);

        // nonce += 1;

        DecryptedBlog memory decrypted_storage;
        bytes[2] memory decryptedp;
        decryptedp[0] = TFHE.reencrypt(p[relayer_id][0], data.publicKey[relayer_id]);
        decryptedp[1] = TFHE.reencrypt(p[relayer_id][1], data.publicKey[relayer_id]);
        
        decrypted_storage.p = decryptedp;
        return decrypted_storage;
    }

    function claimReward(uint8 relayer_id, address caller, uint64 _nonce, bytes memory signature) public {
        assert(verifySignature(relayer_id, _nonce, caller, signature) == true);

        /// here we can check expiration date
        if(rewarded[caller][_nonce] == false){
            rewarded[caller][_nonce] = true;
            reward[msg.sender] += 1;
        }        
    }
  
}

// contract FHEordle is EIP712WithModifier, Initializable {
//     struct PassPair {
//         bytes32 public_part;  // First element of the pair
//         int8 private_part; // Second element of the pair
//     }
//     /// pass
    

//     // constants
//     uint8 expirationTime = 5
//     uint8 relayerNumber = 1
    
//     /// nonce
//     uint256 current_nonce = 0;
    
//     function regenerate(__userAddr, euint8[] secrets) private {
//         // just does the generation of random numbers and 
//         for(uint8 i = 0; i < relayerNumber; i++){
//             bytes32 rndPublic = gen_random_public
//             if (TFHE.eq(privatePass[rndPublic], 0) != true){
//                 // regenerate
//             }
//             privatePass[rndPublic] = secrets[i];
//             // if we can do TFHE.randIntu16 then change it 
//         }
//         //
//     }

//     function get_passes(
//         address __userAddr,
//         bytes32 publicKey
//         bytes calldata signature,
//     ) public view  {

//         bytes32[] memory passes = passBelonings[__userAddr]

//         if(passes.length == 0){
//             revert("No passes found for this user")
//         }
        
//         PassPair memory reencrypted = new PassPair[passes.length];

//         bool expired = false

//         for (uint256 i = 0; i < passes.length; i++) {
//             if(passExpiration[passes[i]] + expirationTime * 60 < block.timestamp){
//                 expired = true;
//                 break;
//             }
//         }

//         if(expired == true){
//             regenerate(__userAddr)
//         }
//         for (uint256 i = 0; i < passes.length; i++) {
//             reencrypted[i] = PassPair({
//                 privatePart : TFHE.reencrypt(privatePass[passes[i]], publicKey)
//                 publicPart : passes[i]
//             })

//         }
//         return reencrypted
//     }

//     function verify_pass(
//         bytes32 public_part,
//         uint8 private_part
//     ) public view {
//         euint8 actual_private_part = privatePass[public_part]

//         uint256 dateOfBirth = passExpiration[public_part]

//         if(block.timestamp  > dateOfBirth + 50 * expirationTime){
//             revert("The pass is expired")
//         }
//         if(TFHE.decrypt(TFHE.eq(actual_private_part, 0)) == true){
//             revert("The pass is not valid");
//         }
       
//         return true;
//     }

//     function generateJwt(relayer_id, caller, nonce, nft, nonce, caller_sig){
//         assert(caller == nft.owner)
//         assert(current_nonce == nonce)
//         // assert(caller_sig.verify(generateJwt, relayer_id, caller, nonce))

//         current_nonce += 1

//     }
//     function acquire(
//         address __userAddr,
//         bytes calldata signature,
//         euint8[] secrets
//     ){
//         /// do stuff to acquire and check balance


//     }

// }