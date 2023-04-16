// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./KassUtils.sol";

contract KassStructs {

    struct WrapperRequest {
        // native token address
        bytes32 tokenAddress;

        // ERC721 or ERC1155
        TokenStandard tokenStandard;

        // Calldata to init the wrapper
        bytes _calldata;
    }

    struct DepositRequest {
        // native token address
        bytes32 tokenAddress;

        // ERC721 or ERC1155
        TokenStandard tokenStandard;

        uint256 tokenId;

        uint256 amount;

        address recipient;
    }
}
