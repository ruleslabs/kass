// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

import "../Deposit/DepositNative1155.t.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Native_Withdraw is TestSetup_1155_Native_Deposit {

    function _1155_basicWithdrawTest(address l1Recipient, uint256 tokenId, uint256 amount) internal {
        // assert balance is empty
        assertEq(_l1NativeToken.balanceOf(l1Recipient, tokenId), 0);

        // mint tokens
        _1155_mintTokens(address(this), tokenId, amount);

        // approve deposit
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // deposit
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId, amount, false);

        // deposit from L2 and withdraw to L1
        uint256[] memory messagePayload = depositOnL1(
            _bytes32_l1NativeToken(),
            l1Recipient,
            tokenId,
            amount,
            TokenStandard.ERC1155
        );
        expectWithdrawOnL1(_bytes32_l1NativeToken(), l1Recipient, tokenId, amount, TokenStandard.ERC1155);
        _kass.withdraw(messagePayload);

        // assert balance was updated
        assertEq(_l1NativeToken.balanceOf(l1Recipient, tokenId), amount);
    }
}

contract Test_1155_Native_Withdraw is TestSetup_1155_Native_Withdraw {

    function test_1155_native_BasicWithdrawFromL2_1() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));

        _1155_basicWithdrawTest(l1Recipient, tokenId, amount);
    }

    function test_1155_native_BasicWithdrawFromL2_2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = 0x2;
        uint256 amount = 0x3;

        _1155_basicWithdrawTest(l1Recipient, tokenId, amount);
    }

    function test_1155_native_BasicWithdrawFromL2_3() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 3"))));
        uint256 tokenId = 0x2 << UINT256_PART_SIZE_BITS;
        uint256 amount = 0x3 << UINT256_PART_SIZE_BITS;

        _1155_basicWithdrawTest(l1Recipient, tokenId, amount);
    }

    function test_1155_native_CannotWithdrawFromL2Twice() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // mint tokens
        _1155_mintTokens(address(this), tokenId, amount);

        // approve deposit
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // deposit
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), 0x1, tokenId, amount, false);

        // deposit from L2
        uint256[] memory messagePayload = depositOnL1(
            _bytes32_l1NativeToken(),
            l1Recipient,
            tokenId,
            amount,
            TokenStandard.ERC1155
        );

        // withdraw
        expectWithdrawOnL1(_bytes32_l1NativeToken(), l1Recipient, tokenId, amount, TokenStandard.ERC1155);
        _kass.withdraw(messagePayload);

        vm.clearMockedCalls();
        vm.expectRevert();
        _kass.withdraw(messagePayload);
    }

    function test_1155_native_CannotWithdrawZeroFromL2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x0;

        // deposit from L2
        uint256[] memory messagePayload = depositOnL1(
            _bytes32_l1NativeToken(),
            l1Recipient,
            tokenId,
            amount,
            TokenStandard.ERC1155
        );

        // withdraw
        vm.expectRevert("Cannot withdraw null amount");
        _kass.withdraw(messagePayload);
    }
}
