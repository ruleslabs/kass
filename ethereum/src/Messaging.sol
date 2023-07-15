// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./StarknetConstants.sol";
import "./Structs.sol";
import "./Utils.sol";
import "./Storage.sol";

abstract contract KassMessaging is KassStorage, StarknetConstants, KassStructs {

    function l2KassAddress() public view returns (uint256) {
        return _state.l2KassAddress;
    }

    function setL2KassAddress(uint256 l2KassAddress_) public virtual {
        _state.l2KassAddress = l2KassAddress_;
    }

    //
    // Internals
    //

    function _parseDepositRequestMessagePayload(
        uint256[] calldata payload
    ) internal pure returns (DepositRequest memory depositRequest) {
        depositRequest.nativeTokenAddress = bytes32(payload[1]);

        depositRequest.recipient = address(uint160(payload[2]));

        depositRequest.tokenId = payload[3] | payload[4] << UINT256_PART_SIZE_BITS;

        depositRequest.amount = payload[5] | payload[6] << UINT256_PART_SIZE_BITS;

        if (payload[0] == DEPOSIT_TO_L1) {

            // no wrapper request

            depositRequest.tokenStandard = TokenStandard.UNKNOWN;
        } else if (payload[0] == DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1) {

            // ERC 721 wrapper request

            depositRequest.tokenStandard = TokenStandard.ERC721;

            depositRequest._calldata = abi.encode(
                KassUtils.felt252ToStr(payload[7]),
                KassUtils.felt252ToStr(payload[8])
            );
        } else if (payload[0] == DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1) {

            // ERC 1155 wrapper request

            depositRequest.tokenStandard = TokenStandard.ERC1155;

            // erase payload for payload[7:]
            assembly {
                payload.length := sub(payload.length, 0x7)
                payload.offset := add(payload.offset, 0xe0) // 7 * 0x20
            }

            depositRequest._calldata = abi.encode(KassUtils.felt252WordsToStr(payload));
        } else {
            revert("Invalid message payload");
        }
    }

    // L1 WRAPPER REQUEST

    function _consumeL1WrapperRequestMessage(uint256[] calldata payload) internal {
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);
    }

    // L1 OWNERSHIP CLAIM

    function _computeL1OwnershipClaimMessage(
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

    function _consumeL1OwnershipClaimMessage(uint256 l2TokenAddress, address l1Owner) internal {
        uint256[] memory payload = _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner);
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);
    }

    // L2 OWNERSHIP CLAIM

    function _computeL2OwnershipClaimMessage(
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

    function _sendL2OwnershipClaimMessage(address l1TokenAddress, uint256 l2Owner, uint256 fee) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeL2OwnershipClaimMessage(l1TokenAddress, l2Owner);

        _sendMessage(handlerSelector, payload, fee);
    }

    // DEPOSIT ON L2

    function _computeTokenDepositOnL2Message(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper
    ) internal view returns (uint256[] memory payload, uint256 handlerSelector) {
        if (requestWrapper) {

            // needs a L2 wrapper

            address l1TokenAddress = address(uint160(uint256(nativeTokenAddress)));

            if (KassUtils.isERC721(l1TokenAddress)) {
                payload = new uint256[](8); // token address + deposit data + name + symbol

                payload[6] = KassUtils.strToFelt252(ERC721(l1TokenAddress).name());
                payload[7] = KassUtils.strToFelt252(ERC721(l1TokenAddress).symbol());

                handlerSelector = WRAPPER_CREATION_AND_WITHDRAW_721_HANDLER_SELECTOR;
            } else if (KassUtils.isERC1155(l1TokenAddress)) {
                uint256[] memory data = KassUtils.strToFelt252Words(ERC1155(l1TokenAddress).uri(0x0));

                payload = new uint256[](data.length + 6); // token address + deposit data + uri

                for (uint8 i = 0; i < data.length; ++i) {
                    payload[i + 6] = data[i];
                }

                handlerSelector = WRAPPER_CREATION_AND_WITHDRAW_1155_HANDLER_SELECTOR;
            } else {
                revert("Kass: Unknown token standard");
            }
        } else {

            // already have/is a wrapper

            payload = new uint256[](6);
        }

        // store L2 token address
        payload[0] = uint256(nativeTokenAddress);

        payload[1] = recipient;

        payload[2] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // low
        payload[3] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // high

        payload[4] = uint128(amount & (UINT256_PART_SIZE - 1)); // low
        payload[5] = uint128(amount >> UINT256_PART_SIZE_BITS); // high

        handlerSelector = WITHDRAW_HANDLER_SELECTOR;
    }

    function _sendTokenDepositMessage(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 fee
    ) internal returns (uint256) {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );

        return _sendMessage(handlerSelector, payload, fee);
    }

    function _startL1ToL2TokenDepositMessageCancellation(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        _state.starknetMessaging.startL1ToL2MessageCancellation(_state.l2KassAddress, handlerSelector, payload, nonce);
    }

    function _cancelL1ToL2TokenDepositMessage(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        _state.starknetMessaging.cancelL1ToL2Message(_state.l2KassAddress, handlerSelector, payload, nonce);
    }

    // WITHDRAW ON L1

    function _consumeWithdrawMessage(uint256[] calldata payload) internal {
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);
    }

    // MESSAGE SENDER

    function _sendMessage(
        uint256 handlerSelector,
        uint256[] memory payload,
        uint256 fee
    ) private returns (uint256) {
        require(msg.value >= fee, "Kass: Insufficent L1 -> L2 fee");

        (, uint256 nonce) = _state.starknetMessaging.sendMessageToL2{ value: fee }(
            _state.l2KassAddress,
            handlerSelector,
            payload
        );
        return nonce;
    }
}
