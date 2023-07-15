// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradedContractMock is UUPSUpgradeable {
    function foo() public pure returns (uint) {
        return 0x42;
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override { }
}
