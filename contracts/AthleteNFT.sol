// SPDX-License-Identifier: GPL-2.0-or-later
//
// Athlete Showcase NFT v.0000001alpha
// by 0xriptide

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AthleteNFT is ERC721Burnable, ERC721URIStorage, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event TokenURIChanged(address indexed sender, uint256 indexed tokenId, string uri);

    constructor() ERC721("AthleteNFT", "AthLEET") {}

    function nftMint(address _mintTo) public onlyOwner {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(_mintTo, newTokenId);

        string memory jsonFile = string(abi.encodePacked('metadata', Strings.toString(newTokenId), '.json'));
        _setTokenURI(newTokenId, jsonFile);

        emit TokenURIChanged(_mintTo, newTokenId, jsonFile);
    }

    function _baseURI() internal pure override returns (string memory){
        return "ipfs://bafkreibmoa5dxvu2nrwk27hxjqkqcgpwdpzeybbpkchnop775licj7kr5u";
    }

    function tokenURI(uint256 tokenId) public view  override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

}
