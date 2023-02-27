// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "openzeppelin-contracts/utils/Context.sol";
import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";

import "./interfaces/IStarknetCore.sol";

contract StarkWayERC1155Bridge is Context {
  IStarknetCore starknetCore;

  constructor(address _starknetCore) {
    starknetCore = IStarknetCore(_starknetCore);
  }

  function createL1Instance(uint256 tokenL2Address, string calldata uri) public returns (address newInstance) {
    // consume L1 instance request payload
    uint256[] memory payload = new uint256[](1);
    payload[0] = strToUint(uri);

    starknetCore.consumeMessageFromL2(tokenL2Address, payload);

    newInstance = address(new ERC1155{salt: bytes32(tokenL2Address)}(uri));
  }

  function strToUint(string memory text) public pure returns (uint256 res) {
    bytes32 stringInBytes32 = bytes32(bytes(text));
    uint256 strLen = bytes(text).length; // TODO: cannot be above 32
    require(strLen <= 32, "String cannot be longer than 32");

    uint256 shift = 256 - 8 * strLen;

    uint256 stringInUint256;
    assembly {
        stringInUint256 := shr(shift, stringInBytes32)
    }
    return stringInUint256;
  }
}
