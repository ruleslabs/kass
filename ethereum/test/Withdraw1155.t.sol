// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract WithdrawTestSetup is KassTestBase {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1WrapperCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI, TokenStandard.ERC1155);
        _l1TokenWrapper = KassERC1155(_kass.createL1Wrapper1155(L2_TOKEN_ADDRESS, L2_TOKEN_URI));
    }

    function _1155_basicWithdrawTest(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        address l1Recipient
    ) internal {
        // assert balance is empty
        assertEq(_l1TokenWrapper.balanceOf(l1Recipient, tokenId), 0);

        // deposit from L2 and withdraw to L1
        depositOnL1(l2TokenAddress, tokenId, amount, l1Recipient, TokenStandard.ERC1155);
        expectWithdrawOnL1(l2TokenAddress, tokenId, amount, l1Recipient, TokenStandard.ERC1155);
        _kass.withdraw1155(l2TokenAddress, tokenId, amount, l1Recipient);

        // assert balance was updated
        assertEq(_l1TokenWrapper.balanceOf(l1Recipient, tokenId), amount);
    }
}

contract WithdrawTest is WithdrawTestSetup {

    function test_1155_BasicWithdrawFromL2_1() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }

    function test_BasicWithdrawFromL2_2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = 0x2;
        uint256 amount = 0x3;

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }

    function test_1155_BasicWithdrawFromL2_3() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 3"))));
        uint256 tokenId = 0x2 << UINT256_PART_SIZE_BITS;
        uint256 amount = 0x3 << UINT256_PART_SIZE_BITS;

        _1155_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }

    function test_1155_CannotWithdrawFromL2WithDifferentTokenIdFromL2Request() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);

        vm.expectRevert();
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId - 1, amount, l1Recipient);
    }

    function test_1155_CannotWithdrawFromL2WithDifferentAmountFromL2Request() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);

        vm.expectRevert();
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId, amount + 1, l1Recipient);
    }

    function test_1155_CannotWithdrawFromL2WithDifferentL1RecipientFromL2Request() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        address fakeL1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);

        vm.expectRevert();
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId, amount, fakeL1Recipient);
    }

    function test_1155_CannotWithdrawFromL2Twice() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);

        // withdraw
        expectWithdrawOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);

        vm.clearMockedCalls();
        vm.expectRevert();
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }

    function test_1155_CannotWithdrawZeroFromL2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x0;

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient, TokenStandard.ERC1155);

        // withdraw
        vm.expectRevert("Cannot withdraw null amount");
        _kass.withdraw1155(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }
}
