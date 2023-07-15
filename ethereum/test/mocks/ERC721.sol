// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract MockERC721 is Context, ERC721, Ownable {

    //
    // Constructor
    //

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _transferOwnership(_msgSender());
    }

    // mint
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    // burn
    function burn(uint256 id) public {
        _burn(id);
    }
}
