// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

import "./DepositWrapped721.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Wrapped_DepositCancel is TestSetup_721_Wrapped_Deposit {

    function _721_mintAndDepositBackOnL2(
        uint256 l2TokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // mint tokens
        _721_mintTokens(sender, tokenId);

        // deposit tokens on L2
        expectDepositOnL2(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, 0x1, false, nonce);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(bytes32(l2TokenAddress), l2Recipient, tokenId, false);

        // check if there's no owner
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenWrapper.ownerOf(tokenId);
    }

    function _721_basicDepositCancelTest(
        uint256 l2TokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // deposit on L1 and send back to L2
        _721_mintAndDepositBackOnL2(l2TokenAddress, l2Recipient, tokenId, nonce);

        // deposit cancel request
        expectDepositCancelRequest(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, 0x1, false, nonce);
        _kass.requestDepositCancel(bytes32(l2TokenAddress), l2Recipient, tokenId, false, nonce);

        // check if there's still no owner
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenWrapper.ownerOf(tokenId);

        // deposit cancel request
        expectDepositCancel(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, 0x1, false, nonce);
        _kass.cancelDeposit(bytes32(l2TokenAddress), l2Recipient, tokenId, false, nonce);

        // check if owner is correct
        assertEq(_l1TokenWrapper.ownerOf(tokenId), sender);
    }
}

contract Test_721_Wrapped_DepositCancel is TestSetup_721_Wrapped_DepositCancel {

    function test_721_wrapped_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        _721_basicDepositCancelTest(L2_TOKEN_ADDRESS, l2Recipient, tokenId, nonce);
    }

    function test_721_wrapped_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_basicDepositCancelTest(L2_TOKEN_ADDRESS, l2Recipient, tokenId, nonce);
    }

    function test_721_wrapped_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_mintAndDepositBackOnL2(L2_TOKEN_ADDRESS, l2Recipient, tokenId, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(bytes32(L2_TOKEN_ADDRESS),l2Recipient, tokenId, false, nonce);
    }

    function test_721_wrapped_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(bytes32(L2_TOKEN_ADDRESS), l2Recipient, tokenId, false, nonce);
    }
}
