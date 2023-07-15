// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/interfaces/IStarknetMessaging.sol";

// solhint-disable no-empty-blocks
contract StarknetMessagingMock is IStarknetMessaging {
    function consumeMessageFromL2(
        uint256 /* fromAddress */,
        uint256[] calldata /* payload */
    ) external pure returns (bytes32) {
        require(false, "Unknown message");
        return bytes32(0x0);
    }

    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32, uint256) { }

    function startL1ToL2MessageCancellation(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external returns (bytes32) { }

    function cancelL1ToL2Message(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external returns (bytes32) { }
}
