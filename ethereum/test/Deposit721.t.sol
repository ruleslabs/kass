// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../src/KassUtils.sol";
import "../src/factory/KassERC721.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Deposit is KassTestBase, ERC721Holder {
    KassERC721 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL, TokenStandard.ERC721);
        _l1TokenInstance = KassERC721(_kass.createL1Instance721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, L2_TOKEN_SYMBOL));
    }
}

contract Test_721_Deposit is TestSetup_721_Deposit {

    function test_721_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint Token
        vm.prank(address(_kass));
        _l1TokenInstance.mint(sender, tokenId);

        // assert token owner is sender
        assertEq(_l1TokenInstance.ownerOf(tokenId), sender);

        expectDepositOnL2(sender, L2_TOKEN_ADDRESS, tokenId, 0x1, l2Recipient, 0x0);
        _kass.deposit721(L2_TOKEN_ADDRESS, tokenId, l2Recipient);

        // assert token does not exist on L1
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenInstance.ownerOf(tokenId);
    }

    function test_721_CannotDepositToL2IfNotOwnerOfToken() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint Token to someone else
        vm.prank(address(_kass));
        _l1TokenInstance.mint(address(0x1), tokenId);

        // try deposit on L2
        vm.expectRevert("You do not own this token");
        _kass.deposit721(L2_TOKEN_ADDRESS, tokenId, l2Recipient);
    }
}
