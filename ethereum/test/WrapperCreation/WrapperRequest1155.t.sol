// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../../src/KassUtils.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassWrapperRequest is KassTestBase {
    ERC1155 public _l1TokenWrapper = new ERC1155(L2_TOKEN_FLAT_URI);
}

contract Test_1155_KassWrapperRequest is TestSetup_1155_KassWrapperRequest {

    function test_1155_L2TokenWrapperRequest() public {
        // create L1 wrapper
        expectL2WrapperRequest(address(_l1TokenWrapper));
        _kass.requestL2Wrapper{ value: L1_TO_L2_MESSAGE_FEE }(address(_l1TokenWrapper));
    }

    function test_1155_CannotDoubleWrap() public {
        // create L1 wrapper
        requestL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
        uint256[] memory messagePayload = expectL1WrapperCreation(
            L2_TOKEN_ADDRESS,
            L2_TOKEN_URI,
            TokenStandard.ERC1155
        );
        address l1TokenWrapper = _kass.createL1Wrapper(messagePayload);

        vm.expectRevert("Kass: Double wrap not allowed");
        _kass.requestL2Wrapper{ value: L1_TO_L2_MESSAGE_FEE }(l1TokenWrapper);
    }
}
