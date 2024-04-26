pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/Reencrypt.sol";
import "./utils/EncryptedErrors.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

// onlyUser? onlyRelayer?
contract FHEordle is EIP712WithModifier, Initializable {
    struct PassPair {
        bytes32 public_part;  // First element of the pair
        int8 private_part; // Second element of the pair
    }
    /// pass
    mapping(bytes32 => euint8) public privatePass
    mapping(bytes32 => uint128) public passExpiration
    mapping(address => bytes32[]) public passBelonings


    // constants
    uint8 expirationTime = 5
    uint8 relayerNumber = 1
    
    
    function regenerate(__userAddr, euint8[] secrets) private {
        // just does the generation of random numbers and 
        for(uint8 i = 0; i < relayerNumber; i++){
            bytes32 rndPublic = gen_random_public
            if (TFHE.eq(privatePass[rndPublic], 0) != true){
                // regenerate
            }
            privatePass[rndPublic] = secrets[i];
            // if we can do TFHE.randIntu16 then change it 
        }
        //
    }

    function get_passes(
        address __userAddr,
        bytes32 publicKey
        bytes calldata signature,
    ) public view  {

        bytes32[] memory passes = passBelonings[__userAddr]

        if(passes.length == 0){
            revert("No passes found for this user")
        }
        
        PassPair memory reencrypted = new PassPair[passes.length];

        bool expired = false

        for (uint256 i = 0; i < passes.length; i++) {
            if(passExpiration[passes[i]] + expirationTime * 60 < block.timestamp){
                expired = true;
                break;
            }
        }

        if(expired == true){
            regenerate(__userAddr)
        }
        for (uint256 i = 0; i < passes.length; i++) {
            reencrypted[i] = PassPair({
                privatePart : TFHE.reencrypt(privatePass[passes[i]], publicKey)
                publicPart : passes[i]
            })

        }
        return reencrypted
    }

    function verify_pass(
        bytes32 public_part,
        uint8 private_part
    ) public view {
        euint8 actual_private_part = privatePass[public_part]

        uint256 dateOfBirth = passExpiration[public_part]

        if(block.timestamp  > dateOfBirth + 50 * expirationTime){
            revert("The pass is expired")
        }
        if(TFHE.decrypt(TFHE.eq(actual_private_part, 0)) == true){
            revert("The pass is not valid");
        }
       
        return true;
    }

    function acquire(
        address __userAddr,
        bytes calldata signature,
        euint8[] secrets
    ){
        /// do stuff to acquire and check balance


    }

}