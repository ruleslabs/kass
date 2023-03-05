// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract StarknetConstants {
    // The selector of the deposit handler in L2.
    // uint256 constant DEPOSIT_SELECTOR = 1285101517810983806491589552491143496277809242732141897358598292095611420389;
    uint256 public constant UINT256_PART_SIZE_BITS = 128;
    uint256 public constant UINT256_PART_SIZE = 2 ** UINT256_PART_SIZE_BITS;

    uint256 public constant REQUEST_L1_INSTANCE = 0;
    uint256 public constant TRANSFER_FROM_STARKNET = 1;
}
