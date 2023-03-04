// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStarknetMessaging {
  /**
    Sends a message to an L2 contract.
  */
  function sendMessageToL2(
    // solhint-disable-next-line var-name-mixedcase
    uint256 to_address,
    uint256 selector,
    uint256[] calldata payload
  ) external;

  /**
    Consumes a message that was sent from an L2 contract.
  */
  function consumeMessageFromL2(
    uint256 fromAddress,
    uint256[] calldata payload
  ) external;
}
