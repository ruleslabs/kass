
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./interfaces/IStarknetMessaging.sol";

contract KassStorage {

    struct State {
        // Address of the starknet messaging contract
        IStarknetMessaging starknetMessaging;

        // L2 Address of the Kass contract
        uint256 l2KassAddress;

        // Address of the Kass ERC1155 token implementation
        address tokenImplementationAddress;

        // initialization status of the implementation
        bool initialized;

        // nonce / depositors mapping
        mapping(uint256 => address) depositors;
    }

    State internal _state;
}
