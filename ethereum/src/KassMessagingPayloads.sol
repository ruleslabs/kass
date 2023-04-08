// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./StarknetConstants.sol";
import "./KassUtils.sol";

abstract contract KassMessagingPayloads is StarknetConstants {
    function instanceCreationMessagePayload(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](data.length + 2);

        if (tokenStandard == TokenStandard.ERC721) {
            payload[0] = REQUEST_L1_721_INSTANCE;
        } else if (tokenStandard == TokenStandard.ERC1155) {
            payload[0] = REQUEST_L1_1155_INSTANCE;
        } else {
            revert("Kass: Unkown token standard");
        }

        // store L2 token address
        payload[1] = l2TokenAddress;

        // store token URI
        for (uint8 i = 0; i < data.length; ++i) {
            payload[i + 2] = KassUtils.strToUint256(data[i]);
        }
    }

    function ownershipClaimMessagePayload(
        uint256 l2TokenAddress,
        address l1Owner
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](3);

        payload[0] = CLAIM_OWNERSHIP;

        // store L2 token address
        payload[1] = l2TokenAddress;

        // store L1 owner
        payload[2] = uint256(uint160(l1Owner));
    }

    function tokenDepositOnL1MessagePayload(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        address l1Recipient
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](7);

        payload[0] = TRANSFER_FROM_STARKNET;

        payload[1] = uint256(uint160(l1Recipient));

        payload[2] = l2TokenAddress;

        payload[3] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // low
        payload[4] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // high

        payload[5] = uint128(amount >> UINT256_PART_SIZE_BITS); // low
        payload[6] = uint128(amount & (UINT256_PART_SIZE - 1)); // high
    }

    function tokenDepositOnL2MessagePayload(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](6);

        payload[0] = l2Recipient;

        payload[1] = l2TokenAddress;

        payload[2] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // low
        payload[3] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // high

        payload[4] = uint128(amount >> UINT256_PART_SIZE_BITS); // low
        payload[5] = uint128(amount & (UINT256_PART_SIZE - 1)); // high
    }
}
