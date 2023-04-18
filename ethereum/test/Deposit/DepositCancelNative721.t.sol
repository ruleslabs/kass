// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

import "./DepositNative721.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Native_DepositCancel is TestSetup_721_Native_Deposit {

    function _721_mintAndDepositBackOnL2(
        bytes32 tokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 nonce
    ) internal {
        address sender = address(this);

        _721_mintTokens(sender, tokenId);

        _l1NativeToken.approve(address(_kass), tokenId);

        // deposit tokens on L2
        expectDepositOnL2(tokenAddress, sender, l2Recipient, tokenId, 0x1, nonce);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(tokenAddress, l2Recipient, tokenId);

        // assert token has been transfered to Kass
        assertEq(_l1NativeToken.ownerOf(tokenId), address(_kass));
    }

    function _721_basicDepositCancelTest(
        bytes32 tokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // deposit on L1 and send back to L2
        _721_mintAndDepositBackOnL2(tokenAddress, l2Recipient, tokenId, nonce);

        // deposit cancel request
        expectDepositCancelRequest(tokenAddress, sender, l2Recipient, tokenId, 0x1, nonce);
        _kass.requestDepositCancel(tokenAddress, l2Recipient, tokenId, nonce);

        // assert token has been transfered to Kass
        assertEq(_l1NativeToken.ownerOf(tokenId), address(_kass));

        // deposit cancel request
        expectDepositCancel(tokenAddress, sender, l2Recipient, tokenId, 0x1, nonce);
        _kass.cancelDeposit(tokenAddress, l2Recipient, tokenId, nonce);

        // check if owner is correct
        assertEq(_l1NativeToken.ownerOf(tokenId), sender);
    }
}

contract Test_721_Native_DepositCancel is TestSetup_721_Native_DepositCancel {

    function test_721_native_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        _721_basicDepositCancelTest(_bytes32_l1NativeToken(), l2Recipient, tokenId, nonce);
    }

    function test_721_native_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_basicDepositCancelTest(_bytes32_l1NativeToken(), l2Recipient, tokenId, nonce);
    }

    function test_721_native_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_mintAndDepositBackOnL2(_bytes32_l1NativeToken(), l2Recipient, tokenId, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(_bytes32_l1NativeToken(),l2Recipient, tokenId, nonce);
    }

    function test_721_native_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(_bytes32_l1NativeToken(), l2Recipient, tokenId, nonce);
    }
}
