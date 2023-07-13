// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Wrapped_Deposit is KassTestBase, ERC1155Holder {
    KassERC1155 public _l1TokenWrapper;

    function setUp() public override {
        super.setUp();

        // create L1 wrapper
        _l1TokenWrapper = KassERC1155(_createL1Wrapper(TokenStandard.ERC1155));
    }

    function _1155_mintTokens(address to, uint256 tokenId, uint256 amount) internal {
        // mint tokens
        vm.prank(address(_kass));
        _l1TokenWrapper.permissionedMint(to, tokenId, amount);
    }

    function _1155_basicDepositTest(
        uint256 l2TokenAddress,
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amountToDepositOnL2,
        bool requestWrapper
    ) internal {
        uint256 balance = _l1TokenWrapper.balanceOf(sender, tokenId);

        // deposit on L2
        _expectDepositOnL2(
            bytes32(l2TokenAddress),
            sender,
            l2Recipient,
            tokenId,
            amountToDepositOnL2,
            requestWrapper,
            0x0
        );
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            bytes32(l2TokenAddress),
            l2Recipient,
            tokenId,
            amountToDepositOnL2,
            requestWrapper
        );

        // check if balance was updated
        assertEq(_l1TokenWrapper.balanceOf(sender, tokenId), balance - amountToDepositOnL2);
    }
}

contract Test_1155_Wrapped_Deposit is TestSetup_1155_Wrapped_Deposit {

    function test_1155_wrapped_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = uint256(keccak256("huge amount")) + 1;
        uint256 amountToDepositOnL2 = uint256(keccak256("huge amount")) / 2;
        bool requestWrapper = false;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposit
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountToDepositOnL2, requestWrapper);
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountToDepositOnL2, requestWrapper);
    }

    function test_1155_wrapped_DepositToL2_2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x42;
        bool requestWrapper = false;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposit
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountToDepositOnL2, requestWrapper);
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountToDepositOnL2, requestWrapper);
    }

    function tes_1155_wrapped_MultipleDifferentDepositToL2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256[2] memory amountsToDepositOnL2 = [uint256(0x42), uint256(0x18)];
        bool requestWrapper = false;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposits
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountsToDepositOnL2[0], requestWrapper);
        _1155_basicDepositTest(_L2_TOKEN_ADDRESS, sender, l2Recipient, tokenId, amountsToDepositOnL2[1], requestWrapper);
    }

    function test_1155_wrapped_CannotDoubleWrap() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x42;
        bool requestWrapper = true;

        // mint Token
        _1155_mintTokens(sender, tokenId, amount);

        vm.expectRevert("Kass: Double wrap not allowed");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            bytes32(_L2_TOKEN_ADDRESS),
            l2Recipient,
            tokenId,
            amount,
            requestWrapper
        );
    }

    function test_1155_wrapped_CannotDepositToL2MoreThanBalance() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x101;
        bool requestWrapper = false;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // deposit on L2
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            bytes32(_L2_TOKEN_ADDRESS),
            l2Recipient,
            tokenId,
            amountToDepositOnL2,
            requestWrapper
        );
    }

    function test_1155_wrapped_CannotDepositZeroToL2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x0;
        bool requestWrapper = false;

        // deposit on L2
        vm.expectRevert("Cannot deposit null amount");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            bytes32(_L2_TOKEN_ADDRESS),
            l2Recipient,
            tokenId,
            amountToDepositOnL1,
            requestWrapper
        );
    }
}
