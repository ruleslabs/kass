// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../../src/KassUtils.sol";
import "../KassTestBase.sol";

import "../Deposit/DepositNative1155.t.sol";

// solhint-disable contract-name-camelcase

contract Test_1155_KassWrapperRequest is TestSetup_1155_Native_Deposit {

    function test_1155_L2TokenWrapperRequest() public {
        address sender = address(this);
        uint256 tokenId = 0x1;
        uint256 amount = 0x1;

        _1155_mintTokens(sender, tokenId, amount);

        _l1NativeToken.setApprovalForAll(address(_kass), true);

        _expectDepositOnL2(_bytes32_l1NativeToken(), sender, 0x1, tokenId, amount, true, 0x1);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId, amount, true);
    }
}
