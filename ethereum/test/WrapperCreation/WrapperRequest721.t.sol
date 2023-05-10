// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../src/KassUtils.sol";
import "../KassTestBase.sol";

import "../Deposit/DepositNative721.t.sol";

// solhint-disable contract-name-camelcase

contract Test_721_KassWrapperRequest is TestSetup_721_Native_Deposit {

    function test_721_L2TokenWrapperRequest() public {
        address sender = address(this);
        uint256 tokenId = 0x1;

        _721_mintTokens(sender, tokenId);

        _l1NativeToken.approve(address(_kass), tokenId);

        expectDepositOnL2(_bytes32_l1NativeToken(), sender, 0x1, tokenId, 0x1, true, 0x1);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId);
    }
}
