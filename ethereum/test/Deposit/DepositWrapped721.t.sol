// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Wrapped_Deposit is KassTestBase, ERC721Holder {
    KassERC721 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // request and create L1 wrapper
        uint256[] memory messagePayload = requestL1WrapperCreation(
            L2_TOKEN_ADDRESS,
            L2_TOKEN_NAME_AND_SYMBOL,
            TokenStandard.ERC721
        );
        _l1TokenWrapper = KassERC721(_kass.createL1Wrapper(messagePayload));
    }

    function _721_mintTokens(address to, uint256 tokenId) internal {
        // mint tokens
        vm.prank(address(_kass));
        _l1TokenWrapper.permissionedMint(to, tokenId);
    }
}

contract Test_721_Wrapped_Deposit is TestSetup_721_Wrapped_Deposit {

    function test_721_wrapped_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint Token
        _721_mintTokens(sender, tokenId);

        // assert token owner is sender
        assertEq(_l1TokenWrapper.ownerOf(tokenId), sender);

        expectDepositOnL2(bytes32(L2_TOKEN_ADDRESS), sender, l2Recipient, tokenId, 0x1, 0x0);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(bytes32(L2_TOKEN_ADDRESS), l2Recipient, tokenId);

        // assert token does not exist on L1
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenWrapper.ownerOf(tokenId);
    }

    function test_721_wrapped_CannotDepositToL2IfNotTokenOwner() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint Token to someone else
        _721_mintTokens(address(0x1), tokenId);

        // try deposit on L2
        vm.expectRevert("You do not own this token");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(bytes32(L2_TOKEN_ADDRESS), l2Recipient, tokenId);
    }
}
