// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassRequestOwnership is KassTestBase {
    KassERC721 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // create ownable L1 native token
        _l1TokenWrapper = new KassERC721();
        _l1TokenWrapper.initialize(abi.encode(_L2_TOKEN_NAME, _L2_TOKEN_SYMBOL));
    }
}

contract Test_721_KassRequestOwnership is TestSetup_721_KassRequestOwnership {

    function test_721_requestOwnershipOnL2() public {
        uint256 l2Owner = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;

        // request ownership on L2
        _expectL2OwnershipRequest(address(_l1TokenWrapper), l2Owner);
        _kass.requestL2Ownership{ value: L1_TO_L2_MESSAGE_FEE }(address(_l1TokenWrapper), l2Owner);
    }

    function test_721_cannotRequestOwnershipOnL2IfNotOwner() public {
        uint256 l2Owner = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        address sender = address(uint160(uint256(keccak256("rando 1"))));

        // give ether to sender
        vm.deal(sender, 1 ether);

        // request ownership on L2
        vm.prank(sender);
        vm.expectRevert("Sender is not the owner");
        _kass.requestL2Ownership{ value: L1_TO_L2_MESSAGE_FEE }(address(_l1TokenWrapper), l2Owner);
    }
}
