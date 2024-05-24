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
    uint64[2] p;
}
struct BlogStorage{
    bytes[] cid;
    uint64[2][] p;
    bytes32[] publicKey;
}

contract FHE_BLOGCrutch is Initializable, ERC721Upgradeable {
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    uint256 public s_tokenCounter;


    
    BlogStorage private data;
    mapping(address => mapping(uint64 => bool)) internal rewarded;
    mapping(address => uint256) public reward;
    address[] private relayer_addresses;

    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant DATA_TYPEHASH = keccak256("Data(uint256 nft,uint8 relayer_id,address caller,uint256 nonce)");
    bytes32 public DOMAIN_SEPARATOR;

    address public owner;
    uint256 public price;
    /// @dev Initializes the contract
    /// @param _data The data for the blog
    /// @param _nft_name The name of the NFT
    /// @param _nft_short_name The short name of the NFT
    function initialize(
        BlogStorage calldata _data,
        address[] calldata _relayer_addresses,
        string calldata _nft_name,
        string calldata _nft_short_name,
        uint256 _price
    ) external initializer{
         __ERC721_init(_nft_name, _nft_short_name);
        // data = _data;
        for (uint256 i = 0; i < _data.cid.length; i++) {
            data.cid.push(_data.cid[i]);
            uint64[2] memory cur_p;
            data.p.push(cur_p);
            data.p[i][0] = _data.p[i][0];
            data.p[i][1] = _data.p[i][1];
            data.publicKey.push(_data.publicKey[i]);
            relayer_addresses.push(_relayer_addresses[i]);
        }
        s_tokenCounter = 0;

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("FheBlog")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
        owner = tx.origin;
        price = _price;
    }

    constructor() {
        _disableInitializers();
    }

    /// @dev Mints a new NFT for native token
    function mintNft() public payable {
        require(msg.value >= 0.01 ether, "FHE_BLOG: insufficient funds");
        
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;

        payable(owner).transfer(msg.value);
    }

    /// @dev Overrides the transferFrom function to make the token non-transferrable
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(from == address(0) || to == address(0), "NonTransferrableERC721Token: non transferrable");
        super.transferFrom(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return TOKEN_URI;
    } 

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    /// @dev Verifies that signer has requested nft from relayer
    /// @param nft The NFT id
    /// @param relayer_id The relayer id
    /// @param nonce The nonce
    /// @param signer The signer address
    /// @param signature The signature
    function verifySignature(
        uint256 nft,
        uint8 relayer_id,
        uint256 nonce,
        address signer,
        bytes memory signature
    ) public view returns (bool) {

        bytes32 dataHash = keccak256(abi.encode(
            DATA_TYPEHASH,
            nft,
            relayer_id,
            signer,
            nonce
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            dataHash
        ));

        address recoveredSigner = ECDSA.recover(digest, signature);
        return signer == recoveredSigner;
    }

    /// @dev Returns the cid of share relayer is responsible for
    function getCid(uint256 relayer_id) public view returns (bytes memory) {
        return data.cid[relayer_id];
    }

    /// @dev Returns a reencrypted key of nft for the relayer
    function generateJwt(uint256 nft, uint8 relayer_id, address caller, uint256 _nonce, bytes memory signature) public view returns (DecryptedBlog memory) {
       
        assert(ownerOf(nft) == caller);
        assert(verifySignature(nft, relayer_id, _nonce, caller, signature) == true);

        // nonce += 1;

        DecryptedBlog memory decrypted_storage;
        uint64[2] memory decryptedp;
        decryptedp[0] = data.p[relayer_id][0];
        decryptedp[1] = data.p[relayer_id][1];
        
        decrypted_storage.p = decryptedp;
        return decrypted_storage;
    }

    /// @dev Claims reward for decryption for the relayer
    function claimReward(uint256 nft, uint8 relayer_id, address caller, uint64 _nonce, bytes memory signature) public {
        
        assert(ownerOf(nft) == caller);
        assert(verifySignature(nft, relayer_id, _nonce, caller, signature) == true);

        /// here we can check expiration date
        if(rewarded[caller][_nonce] == false){
            rewarded[caller][_nonce] = true;
            reward[relayer_addresses[relayer_id]] += 1;
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