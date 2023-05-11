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

        // request L1 wrapper
        depositOnL1(bytes32(L2_TOKEN_ADDRESS), address(0x1), 0x1, 0x1, TokenStandard.ERC1155, L2_TOKEN_URI);
    }
}

contract Test_1155_KassWrapperCreation is TestSetup_1155_KassWrapperCreation {

    function test_1155_L1TokenWrapperUri() public {
        // create L1 wrapper
        uint256[] memory messagePayload = expectWithdrawOnL1(
            bytes32(L2_TOKEN_ADDRESS),
            address(0x1),
            0x1,
            0x1,
            TokenStandard.ERC1155,
            L2_TOKEN_URI
        );
        _kass.withdraw(messagePayload);

        KassERC1155 l1TokenWrapper = KassERC1155(_kass.computeL1TokenAddress(L2_TOKEN_ADDRESS));

        assertEq(l1TokenWrapper.uri(0), string(KassUtils.felt252WordsToStr(L2_TOKEN_URI)));
    }

    function test_1155_DoubleL1WrapperRequest() public {
        _createL1Wrapper(TokenStandard.ERC1155);
        _createL1Wrapper(TokenStandard.ERC1155);
    }
}
