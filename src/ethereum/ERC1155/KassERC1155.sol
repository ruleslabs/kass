// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

// modified version of the oz ERC1155 without constructor for a consistent bytecode
contract KassERC1155 is ERC1155 {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC1155("") { }

    // set uri
    function setURI(string calldata uri_) public virtual {
        // require current uri is empty
        bytes memory currentURI = bytes(uri(0));
        require(currentURI.length == 0, "KassERC1155: URI already set");

        _setURI(uri_);
    }
}
