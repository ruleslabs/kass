// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract MockERC1155 is Context, ERC1155, Ownable {

    //
    // Constructor
    //

    constructor(string memory uri_) ERC1155(uri_) {
        _transferOwnership(_msgSender());
    }

    // mint
    function mint(address to, uint256 id, uint256 amount) public {
        _mint(to, id, amount, "");
    }

    // burn
    function burn(address from, uint256 id, uint256 amount) public {
        _burn(from, id, amount);
    }
}
