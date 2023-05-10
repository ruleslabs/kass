// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

import "./DepositNative1155.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Native_DepositCancel is TestSetup_1155_Native_Deposit {

    function _1155_mintAndDepositOnL2(
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // mint tokens
        _1155_mintTokens(sender, tokenId, amount);

        // test deposit
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
    }

    function _1155_basicDepositCancelTest(
        bytes32 tokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // get balance before deposit
        uint256 balance = _l1NativeToken.balanceOf(sender, tokenId);

        // deposit on L1 and send back to L2
        _1155_mintAndDepositOnL2(l2Recipient, tokenId, amount, requestWrapper, nonce);

        // deposit cancel request
        expectDepositCancelRequest(tokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kass.requestDepositCancel(tokenAddress, l2Recipient, tokenId, amount, requestWrapper, nonce);

        // check if balance still the same
        assertEq(_l1NativeToken.balanceOf(sender, tokenId), balance);

        // deposit cancel request
        expectDepositCancel(tokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kass.cancelDeposit(tokenAddress, l2Recipient, tokenId, amount, requestWrapper, nonce);

        // check if balance was updated
        assertEq(_l1NativeToken.balanceOf(sender, tokenId), balance + amount);
    }
}

contract Test_1155_Native_DepositCancel is TestSetup_1155_Native_DepositCancel {

    function test_1155_native_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));
        bool requestWrapper = false;
        uint256 nonce = uint256(keccak256("huge nonce"));

        _1155_basicDepositCancelTest(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount, requestWrapper, nonce);
    }

    function test_1155_native_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        bool requestWrapper = false;
        uint256 nonce = 0x0;

        _1155_basicDepositCancelTest(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount, requestWrapper, nonce);
    }

    function test_1155_native_DepositCancel_3() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        bool requestWrapper = true;
        uint256 nonce = 0x0;

        _1155_basicDepositCancelTest(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount, requestWrapper, nonce);
    }

    function test_1155_native_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        bool requestWrapper = false;
        uint256 nonce = 0x0;

        _1155_mintAndDepositOnL2(tokenId, l2Recipient, amount, requestWrapper, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount, requestWrapper, nonce);
    }

    function test_1155_native_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        bool requestWrapper = false;
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount, requestWrapper, nonce);
    }
}
