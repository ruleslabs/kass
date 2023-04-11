// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassInstanceCreation is KassTestBase {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
    }
}

contract Test_1155_KassInstanceCreation is TestSetup_1155_KassInstanceCreation {

    function test_1155_L1TokenInstanceComputedAddress() public {
        // pre compute address
        address computedL1TokenAddress = _kass.computeL1TokenAddress(L2_TOKEN_ADDRESS);

        // create L1 instance
        expectL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
        address l1TokenAddress = _kass.createL1Instance1155(L2_TOKEN_ADDRESS, L2_TOKEN_URI);

        assertEq(computedL1TokenAddress, l1TokenAddress);
    }

    function test_1155_L1TokenInstanceUri() public {
        // create L1 instance
        expectL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
        KassERC1155 l1TokenInstance = KassERC1155(_kass.createL1Instance1155(L2_TOKEN_ADDRESS, L2_TOKEN_URI));

        assertEq(l1TokenInstance.uri(0), string(KassUtils.encodeTightlyPacked(L2_TOKEN_URI)));
    }

    function test_1155_CannotCreateL1TokenInstanceWithDifferentL2TokenAddressFromL2Request() public {
        vm.expectRevert();
        _kass.createL1Instance1155(L2_TOKEN_ADDRESS - 1, L2_TOKEN_URI);
    }

    function test_1155_CannotCreateL1TokenInstanceWithDifferentUriFromL2Request() public {
        string[] memory uri = new string[](L2_TOKEN_URI.length);

        // reverse `L2_TOKEN_URI`
        for (uint8 i = 0; i < uri.length; ++i) {
            uri[i] = L2_TOKEN_URI[uri.length - i - 1];
        }

        vm.expectRevert();
        _kass.createL1Instance1155(L2_TOKEN_ADDRESS, uri);
    }
}
