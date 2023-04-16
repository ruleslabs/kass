// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./StarknetConstants.sol";
import "./KassStructs.sol";
import "./KassUtils.sol";

abstract contract KassMessagingPayloads is StarknetConstants, KassStructs {

    // PARSE

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

    function parseDepositRequestMessagePayload(
        uint256[] calldata payload
    ) internal pure returns (DepositRequest memory depositRequest) {
        depositRequest.tokenAddress = bytes32(payload[1]);

        depositRequest.recipient = address(uint160(payload[2]));

        depositRequest.tokenId = payload[3] | payload[4] << UINT256_PART_SIZE_BITS;

        if (payload[0] == TRANSFER_721_FROM_STARKNET) {
            depositRequest.tokenStandard = TokenStandard.ERC721;
        } else if (payload[0] == TRANSFER_1155_FROM_STARKNET) {
            depositRequest.tokenStandard = TokenStandard.ERC1155;

            depositRequest.amount = payload[5] | payload[6] << UINT256_PART_SIZE_BITS;
        } else {
            revert("Invalid message payload");
        }
    }

    // COMPUTE

    function computeL2WrapperRequestMessagePayload(
        address tokenAddress
    ) internal view returns (uint256[] memory payload, uint256 handlerSelector) {
        if (ERC165(tokenAddress).supportsInterface(type(IERC721).interfaceId)) {
            payload = new uint256[](3); // token address + name + symbol

            payload[1] = KassUtils.strToFelt252(ERC721(tokenAddress).name());
            payload[2] = KassUtils.strToFelt252(ERC721(tokenAddress).symbol());

            handlerSelector = INSTANCE_CREATION_721_HANDLER_SELECTOR;
        } else if (ERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)) {
            uint256[] memory data = KassUtils.strToFelt252Words(ERC1155(tokenAddress).uri(0x0));

            payload = new uint256[](data.length + 1); // token address + uri

            for (uint8 i = 0; i < data.length; ++i) {
                payload[i + 1] = data[i];
            }

            handlerSelector = INSTANCE_CREATION_1155_HANDLER_SELECTOR;
        } else {
            revert("Kass: Unkown token standard");
        }

        // store L2 token address
        payload[0] = uint160(tokenAddress);
    }

    function computeL1OwnershipClaimMessagePayload(
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

    function computeL2OwnershipClaimMessagePayload(
        address l1TokenAddress,
        uint256 l2Owner
    ) internal pure returns (uint256[] memory payload, uint256 handlerSelector) {
        payload = new uint256[](2);

        // store L1 token address
        payload[0] = uint256(uint160(l1TokenAddress));

        // store L2 owner
        payload[1] = l2Owner;

        handlerSelector = OWNERSHIP_CLAIM_HANDLER_SELECTOR;
    }

    function computeTokenDepositMessagePayload(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount
    ) internal pure returns (uint256[] memory payload, uint256 handlerSelector) {
        payload = new uint256[](6);

        payload[0] = uint256(tokenAddress);

        payload[1] = recipient;

        payload[2] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // low
        payload[3] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // high

        payload[4] = uint128(amount & (UINT256_PART_SIZE - 1)); // low
        payload[5] = uint128(amount >> UINT256_PART_SIZE_BITS); // high

        handlerSelector = WITHDRAW_HANDLER_SELECTOR;
    }
}
