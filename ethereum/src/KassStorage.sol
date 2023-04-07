
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./interfaces/IStarknetMessaging.sol";

contract KassStorage {

    struct State {
        // Address of the starknet messaging contract
        IStarknetMessaging starknetMessaging;

        // L2 Address of the Kass contract
        uint256 l2KassAddress;

        // Address of the Kass Proxy implementation
        address proxyImplementationAddress;

        // Address of the Kass ERC721 implementation
        address erc721ImplementationAddress;

        // Address of the Kass ERC1155 implementation
        address erc1155ImplementationAddress;

        // (implementation address => initialization status) mapping
        mapping(address implementation => bool initialized) initializedImplementations;

        // (nonce => depositors) mapping
        mapping(uint256 nonce => address depositor) depositors;
    }

    State internal _state;
}
