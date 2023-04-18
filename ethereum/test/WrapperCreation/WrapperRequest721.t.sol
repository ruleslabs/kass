// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../src/KassUtils.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassWrapperRequest is KassTestBase {
    ERC721 public _l1TokenWrapper = new ERC721(L2_TOKEN_NAME, L2_TOKEN_SYMBOL);
}

contract Test_721_KassWrapperRequest is TestSetup_721_KassWrapperRequest {

    function test_721_L2TokenWrapperRequest() public {
        expectL2WrapperRequest(address(_l1TokenWrapper));
        _kass.requestL2Wrapper{ value: L1_TO_L2_MESSAGE_FEE }(address(_l1TokenWrapper));
    }

    function test_721_CannotDoubleWrap() public {
        // create L1 wrapper
        requestL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL, TokenStandard.ERC721);
        uint256[] memory messagePayload = expectL1WrapperCreation(
            L2_TOKEN_ADDRESS,
            L2_TOKEN_NAME_AND_SYMBOL,
            TokenStandard.ERC721
        );
        address l1TokenWrapper = _kass.createL1Wrapper(messagePayload);

        vm.expectRevert("Kass: Double wrap not allowed");
        _kass.requestL2Wrapper{ value: L1_TO_L2_MESSAGE_FEE }(l1TokenWrapper);
    }
}
