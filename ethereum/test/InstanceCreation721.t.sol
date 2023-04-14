// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassWrapperCreation is KassTestBase {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // request L1 instance
        requestL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL, TokenStandard.ERC721);
    }
}

contract Test_721_KassWrapperCreation is TestSetup_721_KassWrapperCreation {

    function test_721_L1TokenWrapperComputedAddress() public {
        // pre compute address
        address computedL1TokenAddress = _kass.computeL1TokenAddress(L2_TOKEN_ADDRESS);

        // create L1 instance
        expectL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL, TokenStandard.ERC721);
        address l1TokenAddress = _kass.createL1Wrapper721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, L2_TOKEN_SYMBOL);

        assertEq(computedL1TokenAddress, l1TokenAddress);
    }

    function test_721_L1TokenWrapperNameAndSymbol() public {
        // create L1 instance
        expectL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL, TokenStandard.ERC721);
        KassERC721 l1TokenWrapper = KassERC721(
            _kass.createL1Wrapper721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, L2_TOKEN_SYMBOL)
        );

        assertEq(l1TokenWrapper.name(), L2_TOKEN_NAME);
        assertEq(l1TokenWrapper.symbol(), L2_TOKEN_SYMBOL);
    }

    function test_721_CannotCreateL1TokenWrapperWithDifferentL2TokenAddressFromL2Request() public {
        vm.expectRevert();
        _kass.createL1Wrapper721(L2_TOKEN_ADDRESS - 1, L2_TOKEN_NAME, L2_TOKEN_SYMBOL);
    }

    function test_721_CannotCreateL1TokenWrapperWithDifferentNameFromL2Request() public {
        vm.expectRevert();
        _kass.createL1Wrapper721(L2_TOKEN_ADDRESS, string.concat(L2_TOKEN_NAME, "foo"), L2_TOKEN_SYMBOL);
    }

    function test_721_CannotCreateL1TokenWrapperWithDifferentSymbolFromL2Request() public {
        vm.expectRevert();
        _kass.createL1Wrapper721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, string.concat(L2_TOKEN_SYMBOL, "foo"));
    }
}
