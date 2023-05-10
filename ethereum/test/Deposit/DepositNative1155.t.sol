// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC1155.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_Native_Deposit is KassTestBase, ERC1155Holder {
    KassERC1155 public _l1NativeToken;
    address public _tokenOwner = address(uint160(uint256(keccak256("owner"))));

    function _bytes32_l1NativeToken() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(_l1NativeToken))));
    }

    function setUp() public override {
        super.setUp();

        vm.startPrank(_tokenOwner);
        _l1NativeToken = new KassERC1155();
        _l1NativeToken.initialize(abi.encode(KassUtils.felt252WordsToStr(L2_TOKEN_URI)));
        vm.stopPrank();
    }

    function _1155_mintTokens(address to, uint256 tokenId, uint256 amount) internal {
        // mint tokens
        vm.prank(_tokenOwner);
        _l1NativeToken.permissionedMint(to, tokenId, amount);
    }

    function _1155_basicDepositTest(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amountToDepositOnL2,
        uint256 nonce
    ) internal {
        uint256 balance = _l1NativeToken.balanceOf(sender, tokenId);

        // check if a L2 wrapper request is needed
        bool createWrapper = _kass.tokenStatus(address(_l1NativeToken)) == TokenStatus.UNKNOWN;

        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // deposit on L2
        expectDepositOnL2(
            _bytes32_l1NativeToken(),
            sender,
            l2Recipient,
            tokenId,
            amountToDepositOnL2,
            createWrapper,
            nonce
        );
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            _bytes32_l1NativeToken(),
            l2Recipient,
            tokenId,
            amountToDepositOnL2
        );

        // check new token status
        assertEq(_kass.tokenStatus(address(_l1NativeToken)) == TokenStatus.NATIVE, true);

        // check if balance was updated
        assertEq(_l1NativeToken.balanceOf(sender, tokenId), balance - amountToDepositOnL2);
    }
}

contract Test_1155_Native_Deposit is TestSetup_1155_Native_Deposit {

    function test_1155_native_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = uint256(keccak256("huge amount")) + 1;
        uint256 amountToDepositOnL2 = uint256(keccak256("huge amount")) / 2;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // approve token transfer
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // test deposit
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountToDepositOnL2, 0x0);
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountToDepositOnL2, 0x0);
    }

    function test_1155_native_DepositToL2_2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x42;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // approve token transfer
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // test deposit
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountToDepositOnL2, 0x0);
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountToDepositOnL2, 0x0);
    }

    function tes_1155_native_MultipleDifferentDepositToL2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256[2] memory amountsToDepositOnL2 = [uint256(0x42), uint256(0x18)];

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // approve token transfer
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // test deposits
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountsToDepositOnL2[0], 0x0);
        _1155_basicDepositTest(sender, l2Recipient, tokenId, amountsToDepositOnL2[1], 0x0);
    }

    function test_1155_native_CannotDepositToL2MoreThanBalance() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToMintOnL1 = 0x100;
        uint256 amountToDepositOnL2 = 0x101;

        // mint some tokens
        _1155_mintTokens(sender, tokenId, amountToMintOnL1);

        // approve token transfer
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // deposit on L2
        vm.expectRevert("ERC1155: insufficient balance for transfer");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            _bytes32_l1NativeToken(),
            l2Recipient,
            tokenId,
            amountToDepositOnL2
        );
    }

    function test_1155_native_CannotDepositToL2Zero() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x0;

        // deposit on L2
        vm.expectRevert("Cannot deposit null amount");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(
            _bytes32_l1NativeToken(),
            l2Recipient,
            tokenId,
            amountToDepositOnL1
        );
    }

    function test_1155_native_CannotDepositToL2IfNotTokenOwner() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        address l1Rando1 = address(uint160(uint256(keccak256("rando 1"))));
        uint256 amount = 0x100;

        // mint Token
        _1155_mintTokens(l1Rando1, tokenId, amount);

        // try deposit on L2
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount);

        // approve kass operator
        vm.prank(l1Rando1);
        _l1NativeToken.setApprovalForAll(address(_kass), true);

        // try deposit on L2
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        _kass.deposit{ value: L1_TO_L2_MESSAGE_FEE }(_bytes32_l1NativeToken(), l2Recipient, tokenId, amount);
    }
}
