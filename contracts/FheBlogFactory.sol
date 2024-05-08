// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import './FheBlog.sol';
contract FHEBlogFactory is EIP712WithModifier {
    address public creator;

    mapping(address => address) public userLastContract;

    mapping(address => uint32) public gamesWon;
    mapping(address => bool) public claimedWin;
    address private immutable implementation;

    constructor(address _implementation) EIP712WithModifier("Authorization token", "1") {
        creator = msg.sender;
        implementation = _implementation;
    }

   
    function createBlog(BlogStorage memory _data, string memory _nft_name, string memory _nft_short_name, bytes32 salt) public{
        address cloneAdd = Clones.cloneDeterministic(implementation,salt);
        FHE_BLOG(cloneAdd).initialize(
            _data,
            _nft_name,
            _nft_short_name
        );
        userLastContract[msg.sender] = cloneAdd;
    }       
    function createBlog(BlogStorage memory _data, bytes32 salt) public{
        createBlog(_data,  'FHE_BLOG', 'FHBL', salt);
    }


    
}