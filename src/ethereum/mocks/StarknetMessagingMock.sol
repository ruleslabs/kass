// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract StarknetMessagingMock {
    function consumeMessageFromL2() external pure {
        require(false, "Unknown message");
    }

    // solhint-disable-next-line no-empty-blocks
    function sendMessageToL2(uint256 toAddress, uint256 selector, uint256[] calldata payload) external { }
}
