// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/ERC1155/KassERC1155.sol";
import "./TestBase.sol";

contract WithdrawTest is KassTestBase {
    KassERC1155 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_URI);
        _l1TokenInstance = KassERC1155(_kass.createL1Instance(L2_TOKEN_ADDRESS, L2_TOKEN_URI));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function depositOnL1WithdrawToL1AndDepositBackOnL2(
        address sender,
        uint256 tokenId,
        uint256 amount,
        address l1Recipient,
        uint256 l2Recipient,
        uint256 nonce
    ) private {
        // deposit tokens on L1
        expectDepositOnL2(sender, L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient, nonce);
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
        _kass.withdraw(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);

        // deposit tokens on L2
        _kass.deposit(L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient);
    }

    function basicDepositCancelTest(
        address sender,
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) private {
        // deposit on L1 and send back to L2
        depositOnL1WithdrawToL1AndDepositBackOnL2(sender, tokenId, amount, sender, l2Recipient, nonce);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), 0x0);

        // deposit cancel request
        expectDepositCancelRequest(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
        _kass.requestDepositCancel(l2TokenAddress, tokenId, amount, l2Recipient, nonce);

        // check if balance still the same
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), 0x0);

        // deposit cancel request
        expectDepositCancel(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
        _kass.cancelDeposit(l2TokenAddress, tokenId, amount, l2Recipient, nonce);

        // check if balance was updated
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amount);
    }

    function test_DepositCancel_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        basicDepositCancelTest(sender, L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient, nonce);
    }

    function test_DepositCancel_2() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        basicDepositCancelTest(sender, L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient, nonce);
    }

    function test_CannotRequestDepositCancelForAnotherDepositor() public {
        address sender = address(this);
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        depositOnL1WithdrawToL1AndDepositBackOnL2(sender, tokenId, amount, sender, l2Recipient, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel(L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient, nonce);
    }

    function test_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x100;
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit(L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient, nonce);
    }
}
