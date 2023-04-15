// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./StarknetConstants.sol";
import "./KassStructs.sol";
import "./KassUtils.sol";

abstract contract KassMessagingPayloads is StarknetConstants, KassStructs {
    function parseWrapperRequestMessagePayload(
        uint256[] calldata payload
    ) internal pure returns (WrapperRequest memory wrapperRequest) {
        wrapperRequest.tokenAddress = bytes32(payload[1]);

        if (payload[0] == REQUEST_L1_721_INSTANCE) {
            wrapperRequest.tokenStandard = TokenStandard.ERC721;

            wrapperRequest._calldata = abi.encode(
                KassUtils.felt252ToStr(payload[2]),
                KassUtils.felt252ToStr(payload[3])
            );
        } else if (payload[0] == REQUEST_L1_1155_INSTANCE) {
            wrapperRequest.tokenStandard = TokenStandard.ERC1155;

            // erase payload for payload[2:]
            assembly {
                payload.length := sub(payload.length, 0x2)
                payload.offset := add(payload.offset, 0x40)
            }

            wrapperRequest._calldata = abi.encode(KassUtils.felt252WordsToStr(payload));
        } else {
            revert("Invalid message payload");
        }
    }

    function l2WrapperCreationMessagePayload(
        address l1TokenAddress,
        uint256[] memory data
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](data.length + 1);

        // store L2 token address
        payload[0] = uint160(l1TokenAddress);

        // store token URI
        for (uint8 i = 0; i < data.length; ++i) {
            payload[i + 1] = data[i];
        }
    }

    function l1OwnershipClaimMessagePayload(
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

    function l2OwnershipClaimMessagePayload(
        address l1TokenAddress,
        uint256 l2Owner
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](2);

        // store L1 token address
        payload[0] = uint256(uint160(l1TokenAddress));

        // store L2 owner
        payload[1] = l2Owner;
    }

    function tokenDepositOnL1MessagePayload(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        address l1Recipient,
        TokenStandard tokenStandard
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](7);

        if (tokenStandard == TokenStandard.ERC721) {
            payload[0] = TRANSFER_721_FROM_STARKNET;
        } else if (tokenStandard == TokenStandard.ERC1155) {
            payload[0] = TRANSFER_1155_FROM_STARKNET;
        } else {
            revert("Kass: Unkown token standard");
        }

        payload[1] = l2TokenAddress;

        payload[2] = uint256(uint160(l1Recipient));

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

        payload[0] = l2TokenAddress;

        payload[1] = l2Recipient;

        payload[2] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // low
        payload[3] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // high

        payload[4] = uint128(amount >> UINT256_PART_SIZE_BITS); // low
        payload[5] = uint128(amount & (UINT256_PART_SIZE - 1)); // high
    }
}
