// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Wrapped_Withdraw is KassTestBase {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // create L1 wrapper
        _l1TokenWrapper = KassERC1155(_createL1Wrapper(TokenStandard.ERC1155));
    }

    function _1155_basicWithdrawTest(
        uint256 l2TokenAddress,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount
    ) internal {
        // assert balance is empty
        assertEq(_l1TokenWrapper.balanceOf(l1Recipient, tokenId), 0);

        // deposit from L2 and withdraw to L1
       uint256[] memory messagePayload = depositOnL1(
            bytes32(l2TokenAddress),
            l1Recipient,
            tokenId,
            amount,
            TokenStandard.ERC1155
        );
        expectWithdrawOnL1(bytes32(l2TokenAddress), l1Recipient, tokenId, amount, TokenStandard.ERC1155);
        _kass.withdraw(messagePayload);

        // assert balance was updated
        assertEq(_l1TokenWrapper.balanceOf(l1Recipient, tokenId), amount);
    }
}

contract Test_1155_Wrapped_Withdraw is TestSetup_1155_Wrapped_Withdraw {

    function test_1155_wrapped_BasicWithdrawFromL2_1() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, l1Recipient, tokenId, amount);
    }

    function test_1155_wrapped_BasicWithdrawFromL2_2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = 0x2;
        uint256 amount = 0x3;

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, l1Recipient, tokenId, amount);
    }

    function test_1155_wrapped_BasicWithdrawFromL2_3() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 3"))));
        uint256 tokenId = 0x2 << UINT256_PART_SIZE_BITS;
        uint256 amount = 0x3 << UINT256_PART_SIZE_BITS;

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, l1Recipient, tokenId, amount);
    }

    function test_1155_wrapped_CannotWithdrawFromL2Twice() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        uint256[] memory messagePayload = depositOnL1(
            bytes32(L2_TOKEN_ADDRESS),
            l1Recipient,
            tokenId,
            amount,
            TokenStandard.ERC1155
        );

        // withdraw
        expectWithdrawOnL1(bytes32(L2_TOKEN_ADDRESS), l1Recipient, tokenId, amount, TokenStandard.ERC1155);
        _kass.withdraw(messagePayload);

        vm.clearMockedCalls();
        vm.expectRevert();
        _kass.withdraw(messagePayload);
    }

    function test_1155_wrapped_CannotWithdrawZeroFromL2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x0;

        // deposit from L2
        uint256[] memory messagePayload = depositOnL1(
            bytes32(L2_TOKEN_ADDRESS),
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
