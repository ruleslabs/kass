// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassWrapperCreation is KassTestBase {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // request L1 instance
        requestL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
    }
}

contract Test_1155_KassWrapperCreation is TestSetup_1155_KassWrapperCreation {

    function test_1155_L1TokenWrapperComputedAddress() public {
        // pre compute address
        address computedL1TokenAddress = _kass.computeL1TokenAddress(L2_TOKEN_ADDRESS);

        // create L1 instance
        uint256[] memory messagePayload = expectL1WrapperCreation(
            L2_TOKEN_ADDRESS,
            L2_TOKEN_URI,
            TokenStandard.ERC1155);
        address l1TokenAddress = _kass.createL1Wrapper(messagePayload);

        assertEq(computedL1TokenAddress, l1TokenAddress);
    }

    function test_1155_L1TokenWrapperUri() public {
        // create L1 instance
        uint256[] memory messagePayload = expectL1WrapperCreation(
            L2_TOKEN_ADDRESS,
            L2_TOKEN_URI,
            TokenStandard.ERC1155
        );
        KassERC1155 l1TokenWrapper = KassERC1155(_kass.createL1Wrapper(messagePayload));

        assertEq(l1TokenWrapper.uri(0), string(KassUtils.felt252WordsToStr(L2_TOKEN_URI)));
    }
}
