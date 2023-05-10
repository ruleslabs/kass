// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassWrapperCreation is KassTestBase {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // request L1 wrapper
        depositOnL1(bytes32(L2_TOKEN_ADDRESS), address(0x1), 0x1, 0x1, TokenStandard.ERC721, L2_TOKEN_NAME_AND_SYMBOL);
    }
}

contract Test_721_KassWrapperCreation is TestSetup_721_KassWrapperCreation {

    function test_721_L1TokenWrapperNameAndSymbol() public {
        // create L1 wrapper
        uint256[] memory messagePayload = expectWithdrawOnL1(
            bytes32(L2_TOKEN_ADDRESS),
            address(0x1),
            0x1,
            0x1,
            TokenStandard.ERC721,
            L2_TOKEN_NAME_AND_SYMBOL
        );
        _kass.withdraw(messagePayload);

        KassERC721 l1TokenWrapper = KassERC721(_kass.computeL1TokenAddress(L2_TOKEN_ADDRESS));

        assertEq(bytes(l1TokenWrapper.name()).length, bytes(L2_TOKEN_NAME).length);
        assertEq(l1TokenWrapper.symbol(), L2_TOKEN_SYMBOL);
    }
}
