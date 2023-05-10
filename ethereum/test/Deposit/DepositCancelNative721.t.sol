// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

import "./DepositNative721.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Native_DepositCancel is TestSetup_721_Native_Deposit {

    function _721_mintAndDepositOnL2(uint256 l2Recipient, uint256 tokenId, uint256 nonce) internal {
        address sender = address(this);

        // mint Token
        _721_mintTokens(sender, tokenId);

        // test deposit
        _721_basicDepositTest(sender, l2Recipient, tokenId, nonce);
    }

    function _721_basicDepositCancelTest(uint256 l2Recipient, uint256 tokenId, uint256 nonce) internal {
        address sender = address(this);

        // check if a L2 wrapper request is needed
        bool createWrapper = _kass.tokenStatus(address(_l1NativeToken)) == TokenStatus.UNKNOWN;

        // deposit on L1 and send back to L2
        _721_mintAndDepositOnL2(l2Recipient, tokenId, nonce);

        // deposit cancel request
        expectDepositCancelRequest(_bytes32_l1NativeToken(), sender, l2Recipient, tokenId, 0x1, createWrapper, nonce);
        _kass.requestDepositCancel(_bytes32_l1NativeToken(), l2Recipient, tokenId, createWrapper, nonce);

        // assert token has been transfered to Kass
        assertEq(_l1NativeToken.ownerOf(tokenId), address(_kass));

        // deposit cancel request
        expectDepositCancel(_bytes32_l1NativeToken(), sender, l2Recipient, tokenId, 0x1, createWrapper, nonce);
        _kass.cancelDeposit(_bytes32_l1NativeToken(), l2Recipient, tokenId, createWrapper, nonce);

        // check if owner is correct
        assertEq(_l1NativeToken.ownerOf(tokenId), sender);
    }
}

contract Test_721_Native_DepositCancel is TestSetup_721_Native_DepositCancel {

    function test_721_native_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        _721_basicDepositCancelTest(l2Recipient, tokenId, nonce);
    }

    function test_721_native_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_basicDepositCancelTest(l2Recipient, tokenId, nonce);
    }

    function test_721_native_DepositCancelWithoutWrapperRequest() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        // successful deposit with wrapper creation first
        _721_mintAndDepositOnL2(l2Recipient, tokenId + 1, nonce);

        _721_basicDepositCancelTest(l2Recipient, tokenId, nonce);
    }

    function test_721_native_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_mintAndDepositOnL2(l2Recipient, tokenId, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(_bytes32_l1NativeToken(),l2Recipient, tokenId, true, nonce);
    }

    function test_721_native_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(_bytes32_l1NativeToken(), l2Recipient, tokenId, true, nonce);
    }
}
