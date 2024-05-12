// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import './FheBlog.sol';
contract FHEBlogFactory is EIP712WithModifier {
    address public creator;

    mapping(uint256 => address) public blogs;
    uint256 public blogsCount;
    address private immutable implementation;

    constructor(address _implementation) EIP712WithModifier("Authorization token", "1") {
        creator = msg.sender;
        implementation = _implementation;
        blogsCount = 0;
    }

    function getBlogAddress(bytes32 salt) public view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt);
    }
   
    function createBlog(BlogStorage calldata _data, string calldata _nft_name, string calldata _nft_short_name, bytes32 salt) public{
        address cloneAdd = Clones.cloneDeterministic(implementation,salt);
        FHE_BLOG(cloneAdd).initialize(
            _data,
            _nft_name,
            _nft_short_name
        );
        blogs[blogsCount] = cloneAdd;
        blogsCount++;
    }       
    function createBlog(BlogStorage calldata _data, bytes32 salt) public{
        address cloneAdd = Clones.cloneDeterministic(implementation,salt);
        FHE_BLOG(cloneAdd).initialize(
            _data,
            'FHE_BLOG',
            'FHBL'
        );
        blogs[blogsCount] = cloneAdd;
        blogsCount++;
    }


    
}