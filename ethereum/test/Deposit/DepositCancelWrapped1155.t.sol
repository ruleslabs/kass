// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

import "./DepositWrapped1155.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Wrapped_DepositCancel is TestSetup_1155_Wrapped_Deposit {

    function _1155_mintAndDepositBackOnL2(
        uint256 l2TokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) internal {
        address sender = address(this);

        uint256 balance = _l1TokenWrapper.balanceOf(sender, tokenId);

        // mint tokens
        _1155_mintTokens(sender, tokenId, amount);

        // deposit tokens on L2
        expectDepositOnL2(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount, nonce);
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(bytes32(l2TokenAddress), l2Recipient, tokenId, amount);

        // check if balance is correct
        assertEq(_l1TokenWrapper.balanceOf(sender, tokenId), balance);
    }

    function _1155_basicDepositCancelTest(
        uint256 l2TokenAddress,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) internal {
        address sender = address(this);

        uint256 balance = _l1TokenWrapper.balanceOf(sender, tokenId);

        // deposit on L1 and send back to L2
        _1155_mintAndDepositBackOnL2(l2TokenAddress, l2Recipient, tokenId, amount, nonce);

        // deposit cancel request
        expectDepositCancelRequest(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount, nonce);
        _kass.requestDepositCancel(bytes32(l2TokenAddress), l2Recipient, tokenId, amount, nonce);

        // check if balance still the same
        assertEq(_l1TokenWrapper.balanceOf(sender, tokenId), balance);

        // deposit cancel request
        expectDepositCancel(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount, nonce);
        _kass.cancelDeposit(bytes32(l2TokenAddress), l2Recipient, tokenId, amount, nonce);

        // check if balance was updated
        assertEq(_l1TokenWrapper.balanceOf(sender, tokenId), balance + amount);
    }
}

contract Test_1155_Wrapped_DepositCancel is TestSetup_1155_Wrapped_DepositCancel {

    function test_1155_wrapped_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        _1155_basicDepositCancelTest(L2_TOKEN_ADDRESS, l2Recipient, tokenId, amount, nonce);
    }

    function test_1155_wrapped_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        _1155_basicDepositCancelTest(L2_TOKEN_ADDRESS, l2Recipient, tokenId, amount, nonce);
    }

    function test_1155_wrapped_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        _1155_mintAndDepositBackOnL2(L2_TOKEN_ADDRESS, tokenId, l2Recipient, amount, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(bytes32(L2_TOKEN_ADDRESS), l2Recipient, tokenId, amount, nonce);
    }

    function test_1155_wrapped_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(bytes32(L2_TOKEN_ADDRESS), l2Recipient, tokenId, amount, nonce);
    }
}
