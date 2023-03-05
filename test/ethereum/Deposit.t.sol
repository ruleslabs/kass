// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/ethereum/KassUtils.sol";
import "../../src/ethereum/ERC1155/KassERC1155.sol";
import "./KassTestBase.sol";

contract WithdrawTest is KassTestBase {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI);
        _l1TokenInstance = KassERC1155(_kassBridge.createL1Instance(L2_TOKEN_ADDRESS, L2_TOKEN_URI));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function depositAndWithdrawToL1(uint256 tokenId, uint256 amount, address l1Recipient) private {
        // deposit tokens
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
        _kassBridge.withdraw(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
    }

    function test_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = uint256(keccak256("huge amount"));
        uint256 amountTodepositOnL1 = uint256(keccak256("huge amount")) - 0x42;

        // deposit from L2
        depositAndWithdrawToL1(tokenId, amountToDepositOnL1, sender);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1);

        // deposit on L2
        expectdepositOnL1(sender, L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);

        // check if balance was updated
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1 - amountTodepositOnL1);
    }

    function test_DepositToL2_2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x100;
        uint256 amountTodepositOnL1 = 0x42;

        // deposit from L2
        depositAndWithdrawToL1(tokenId, amountToDepositOnL1, sender);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1);

        // deposit on L2
        expectdepositOnL1(sender, L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);

        // check if balance was updated
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1 - amountTodepositOnL1);
    }

    function test_MultipleDepositToL2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x100;

        // solhint-disable-next-line var-name-mixedcase
        uint256 amountTodepositOnL1_1 = 0x42;
        // solhint-disable-next-line var-name-mixedcase
        uint256 amountTodepositOnL1_2 = 0x18;

        // deposit from L2
        depositAndWithdrawToL1(tokenId, amountToDepositOnL1, sender);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1);

        // deposit on L2
        expectdepositOnL1(sender, L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1_1, l2Recipient);
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1_1, l2Recipient);

        expectdepositOnL1(sender, L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1_2, l2Recipient);
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1_2, l2Recipient);

        // check if balance was updated
        assertEq(
            _l1TokenInstance.balanceOf(sender, tokenId),
            amountToDepositOnL1 - amountTodepositOnL1_1 - amountTodepositOnL1_2
        );
    }

    function test_CannotDepositToL2MoreThanBalance() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountToDepositOnL1 = 0x100;
        uint256 amountTodepositOnL1 = 0x101;

        // deposit from L2
        depositAndWithdrawToL1(tokenId, amountToDepositOnL1, sender);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amountToDepositOnL1);

        // deposit on L2
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);
    }

    function test_CannotDepositToL2Zero() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amountTodepositOnL1 = 0x0;

        // deposit on L2
        vm.expectRevert("Cannot deposit null amount");
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amountTodepositOnL1, l2Recipient);
    }
}
