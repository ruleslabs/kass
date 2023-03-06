// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

// solhint-disable no-empty-blocks
contract StarknetMessagingMock {
    function consumeMessageFromL2() external pure {
        require(false, "Unknown message");
    }

    function sendMessageToL2(uint256 toAddress, uint256 selector, uint256[] calldata payload) external { }

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
