// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

abstract contract StarknetConstants {
    // HANDLER SELECTORS
    uint256 internal constant INSTANCE_CREATION_721_HANDLER_SELECTOR = 0x0;
    uint256 internal constant INSTANCE_CREATION_1155_HANDLER_SELECTOR = 0x0;

    uint256 internal constant OWNERSHIP_CLAIM_HANDLER_SELECTOR = 0x0;

    uint256 internal constant WITHDRAW_HANDLER_SELECTOR = 0x0;

    // MESSAGE ID

    uint256 internal constant REQUEST_L1_721_INSTANCE = uint32(bytes4(keccak256("REQUEST_L1_721_INSTANCE")));
    uint256 internal constant REQUEST_L1_1155_INSTANCE = uint32(bytes4(keccak256("REQUEST_L1_1155_INSTANCE")));

    uint256 internal constant REQUEST_L2_721_INSTANCE = uint32(bytes4(keccak256("REQUEST_L2_721_INSTANCE")));
    uint256 internal constant REQUEST_L2_1155_INSTANCE = uint32(bytes4(keccak256("REQUEST_L2_1155_INSTANCE")));

    uint256 internal constant TRANSFER_FROM_STARKNET = uint32(bytes4(keccak256("TRANSFER_FROM_STARKNET")));

    uint256 internal constant CLAIM_OWNERSHIP = uint32(bytes4(keccak256("CLAIM_OWNERSHIP")));

    // CAIRO CONSTANTS

    uint256 internal constant UINT256_PART_SIZE_BITS = 128;
    uint256 internal constant UINT256_PART_SIZE = 2 ** UINT256_PART_SIZE_BITS;
}
