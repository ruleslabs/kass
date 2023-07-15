// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

abstract contract StarknetConstants {
    // HANDLER SELECTORS

    uint256 internal constant WRAPPER_CREATION_AND_WITHDRAW_721_HANDLER_SELECTOR = 0x0;
    uint256 internal constant WRAPPER_CREATION_AND_WITHDRAW_1155_HANDLER_SELECTOR = 0x0;

    uint256 internal constant WITHDRAW_HANDLER_SELECTOR = 0x0;

    uint256 internal constant OWNERSHIP_CLAIM_HANDLER_SELECTOR = 0x0;

    // MESSAGE ID

    uint256 internal constant REQUEST_L1_721_WRAPPER = uint32(bytes4(keccak256("REQUEST_L1_721_WRAPPER")));
    uint256 internal constant REQUEST_L1_1155_WRAPPER = uint32(bytes4(keccak256("REQUEST_L1_1155_WRAPPER")));

    uint256 internal constant DEPOSIT_TO_L1 = uint32(bytes4(keccak256("DEPOSIT_TO_L1")));
    uint256 internal constant DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1 =
        uint32(bytes4(keccak256("DEPOSIT_AND_REQUEST_721_TO_L1")));
    uint256 internal constant DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1 =
        uint32(bytes4(keccak256("DEPOSIT_AND_REQUEST_1155_TO_L1")));

    uint256 internal constant CLAIM_OWNERSHIP = uint32(bytes4(keccak256("CLAIM_OWNERSHIP")));

    // CAIRO CONSTANTS

    uint256 internal constant UINT256_PART_SIZE_BITS = 128;
    uint256 internal constant UINT256_PART_SIZE = 2 ** UINT256_PART_SIZE_BITS;
}
