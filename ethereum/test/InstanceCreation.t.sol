// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

contract KassInstanceCreationTest is KassTestBase {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI);
    }

    function test_L1TokenInstanceComputedAddress() public {
        // pre compute address
        address computedL1TokenAddress = _kass.computeL1TokenAddress(L2_TOKEN_ADDRESS);

        // create L1 instance
        expectL1InstanceCreation(L2_TOKEN_ADDRESS);
        address l1TokenAddress = _kass.createL1Instance(L2_TOKEN_ADDRESS, L2_TOKEN_URI);

        assertEq(computedL1TokenAddress, l1TokenAddress);
    }

    function test_L1TokenInstanceUri() public {
        // create L1 instance
        expectL1InstanceCreation(L2_TOKEN_ADDRESS);
        KassERC1155 l1TokenInstance = KassERC1155(_kass.createL1Instance(L2_TOKEN_ADDRESS, L2_TOKEN_URI));

        assertEq(l1TokenInstance.uri(0), KassUtils.concat(L2_TOKEN_URI));
    }

    function test_CannotCreateL1TokenInstanceWithDifferentL2TokenAddressFromL2Request() public {
        vm.expectRevert();
        _kass.createL1Instance(L2_TOKEN_ADDRESS - 1, L2_TOKEN_URI);
    }

    function test_CannotCreateL1TokenInstanceWithDifferentUriFromL2Request() public {
        string[] memory uri = new string[](L2_TOKEN_URI.length);

        // reverse `L2_TOKEN_URI`
        for (uint8 i = 0; i < uri.length; ++i) {
            uri[i] = L2_TOKEN_URI[uri.length - i - 1];
        }

        vm.expectRevert();
        _kass.createL1Instance(L2_TOKEN_ADDRESS, uri);
    }
}
