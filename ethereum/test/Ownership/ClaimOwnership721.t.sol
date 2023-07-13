// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassClaimOwnership is KassTestBase {
    KassERC721 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // create L1 wrapper
        _l1TokenWrapper = KassERC721(_createL1Wrapper(TokenStandard.ERC721));
    }
}

contract Test_721_KassClaimOwnership is TestSetup_721_KassClaimOwnership {

    function test_721__claimOwnershipOnL1() public {
        address l1Owner = address(this);

        // claim ownership on L2
        _claimOwnershipOnL1(_L2_TOKEN_ADDRESS, l1Owner);
        _expectL1OwnershipClaim(_L2_TOKEN_ADDRESS, l1Owner);
        _kass.claimL1Ownership(_L2_TOKEN_ADDRESS);

        assertEq(_l1TokenWrapper.owner(), l1Owner);
    }
}
