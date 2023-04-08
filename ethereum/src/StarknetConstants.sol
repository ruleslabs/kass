// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

abstract contract StarknetConstants {
    // The selector of the deposit handler in L2.
    uint256 internal constant DEPOSIT_HANDLER_SELECTOR = 0x0;

    uint256 internal constant UINT256_PART_SIZE_BITS = 128;
    uint256 internal constant UINT256_PART_SIZE = 2 ** UINT256_PART_SIZE_BITS;

    uint256 internal constant REQUEST_L1_721_INSTANCE = 721;
    uint256 internal constant REQUEST_L1_1155_INSTANCE = 1155;
    uint256 internal constant TRANSFER_FROM_STARKNET = 1;
    uint256 internal constant CLAIM_OWNERSHIP = 2;
}
