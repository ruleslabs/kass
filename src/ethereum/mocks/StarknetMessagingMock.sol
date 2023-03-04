// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract StarknetMessagingMock {
    function consumeMessageFromL2() external pure {
        require(false, "Unknown message");
    }
}
