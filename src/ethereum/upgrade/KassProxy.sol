// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract KassProxy is ERC1967Proxy {
    // solhint-disable-next-line no-empty-blocks
    constructor (address setup, bytes memory initData) ERC1967Proxy(setup, initData) { }
}
