// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassRequestOwnership is KassTestBase {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // create ownable L1 native token
        _l1TokenInstance = new KassERC1155();
        _l1TokenInstance.initialize(abi.encode(L2_TOKEN_FLAT_URI));
    }
}

contract Test_1155_KassRequestOwnership is TestSetup_1155_KassRequestOwnership {

    function test_1155_requestOwnershipOnL2() public {
        uint256 l2Owner = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;

        // request ownership on L2
        expectL2OwnershipRequest(address(_l1TokenInstance), l2Owner);
        _kass.requestL2Ownership(address(_l1TokenInstance), l2Owner);
    }

    function test_1155_cannotRequestOwnershipOnL2IfNotOwner() public {
        uint256 l2Owner = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;

        // request ownership on L2
        vm.prank(address(0x1));
        vm.expectRevert("Sender is not the owner");
        _kass.requestL2Ownership(address(_l1TokenInstance), l2Owner);
    }
}
