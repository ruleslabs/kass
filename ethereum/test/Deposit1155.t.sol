// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Deposit is KassTestBase, ERC1155Holder {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI);
        _l1TokenInstance = KassERC1155(_kass.createL1Instance1155(L2_TOKEN_ADDRESS, L2_TOKEN_URI));
    }

    function _1155_mintTokens(address to, uint256 tokenId, uint256 amount) internal {
        // deposit tokens
        vm.prank(address(_kass));
        _l1TokenInstance.mint(to, tokenId, amount);
    }

    function _1155_basicDepositTest(
        address sender,
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amountToDepositOnL2,
        uint256 l2Recipient
    ) internal {
        uint256 balance = _l1TokenInstance.balanceOf(sender, tokenId);

        // deposit on L2
        expectDepositOnL2(sender, l2TokenAddress, tokenId, amountToDepositOnL2, l2Recipient, 0x0);
        _kass.deposit1155(l2TokenAddress, tokenId, amountToDepositOnL2, l2Recipient);

        // check if balance was updated
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), balance - amountToDepositOnL2);
    }
}

contract Test_1155_Deposit is TestSetup_1155_Deposit {

    function test_1155_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = uint256(keccak256("huge amount"));
        uint256 amountToDepositOnL2 = uint256(keccak256("huge amount")) - 0x42;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposit
        _1155_basicDepositTest(sender, L2_TOKEN_ADDRESS, tokenId, amountToDepositOnL2, l2Recipient);
    }

    function test_1155_DepositToL2_2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x42;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposit
        _1155_basicDepositTest(sender, L2_TOKEN_ADDRESS, tokenId, amountToDepositOnL2, l2Recipient);
    }

    function tes_1155t_MultipleDepositToL2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256[2] memory amountsToDepositOnL2 = [uint256(0x42), uint256(0x18)];

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // test deposits
        _1155_basicDepositTest(sender, L2_TOKEN_ADDRESS, tokenId, amountsToDepositOnL2[0], l2Recipient);
        _1155_basicDepositTest(sender, L2_TOKEN_ADDRESS, tokenId, amountsToDepositOnL2[1], l2Recipient);
    }

    function test_1155_CannotDepositToL2MoreThanBalance() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x101;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // deposit on L2
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        _kass.deposit1155(L2_TOKEN_ADDRESS, tokenId, amountToDepositOnL2, l2Recipient);
    }

    function test_1155_CannotDepositToL2Zero() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x0;

        // deposit on L2
        vm.expectRevert("Cannot deposit null amount");
        _kass.deposit1155(L2_TOKEN_ADDRESS, tokenId, amountToDepositOnL1, l2Recipient);
    }
}
