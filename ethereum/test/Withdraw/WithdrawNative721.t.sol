// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../KassTestBase.sol";

import "../Deposit/DepositNative721.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Native_Withdraw is TestSetup_721_Native_Deposit {

    function _721_basicWithdrawTest(address l1Recipient, uint256 tokenId) internal {
        // assert token does not exist on L1
        vm.expectRevert("ERC721: invalid token ID");
        _l1NativeToken.ownerOf(tokenId);

        // mint tokens
        _721_mintTokens(address(this), tokenId);

        // approve deposit
        _l1NativeToken.approve(address(_kass), tokenId);

        // deposit
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId);

        // deposit from L2 and withdraw to L1
        uint256[] memory messagePayload = depositOnL1(
            _bytes32_l1NativeToken(),
            l1Recipient,
            tokenId,
            0,
            TokenStandard.ERC721
        );
        expectWithdrawOnL1(_bytes32_l1NativeToken(), l1Recipient, tokenId, 0, TokenStandard.ERC721);
        _kass.withdraw(messagePayload);

        // assert token owner is l1Recipient
        assertEq(_l1NativeToken.ownerOf(tokenId), l1Recipient);
    }
}

contract Test_721_Native_Withdraw is TestSetup_721_Native_Withdraw {

    function test_721_native_BasicWithdrawFromL2_1() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        _721_basicWithdrawTest(l1Recipient, tokenId);
    }

    function test_721_native_BasicWithdrawFromL2_2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = 0x2;

        _721_basicWithdrawTest(l1Recipient, tokenId);
    }

    function test_721_native_BasicWithdrawFromL2_3() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 3"))));
        uint256 tokenId = 0x2 << UINT256_PART_SIZE_BITS;

        _721_basicWithdrawTest(l1Recipient, tokenId);
    }

    function test_native_CannotWithdrawFromL2Twice() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint tokens
        _721_mintTokens(address(this), tokenId);

        // approve deposit
        _l1NativeToken.approve(address(_kass), tokenId);

        // deposit
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId);

        // deposit from L2
        uint256[] memory messagePayload = depositOnL1(
            _bytes32_l1NativeToken(),
            l1Recipient,
            tokenId,
            0,
            TokenStandard.ERC721
        );

        // withdraw
        expectWithdrawOnL1(_bytes32_l1NativeToken(), l1Recipient, tokenId, 0, TokenStandard.ERC721);
        _kass.withdraw(messagePayload);

        vm.clearMockedCalls();
        vm.expectRevert();
        _kass.withdraw(messagePayload);
    }
}
