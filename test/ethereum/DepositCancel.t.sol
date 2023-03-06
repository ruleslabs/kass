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

    function depositWithdrawToL1AndDepositBackOnL2(
        uint256 tokenId,
        uint256 amount,
        address l1Recipient,
        uint256 l2Recipient
    ) private {
        // deposit tokens on L1
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);
        _kassBridge.withdraw(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);

        // deposit tokens on L2
        _kassBridge.deposit(L2_TOKEN_ADDRESS, tokenId, amount, l2Recipient);
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
        depositWithdrawToL1AndDepositBackOnL2(tokenId, amount, sender, l2Recipient);
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), 0x0);

        // deposit cancel request
        expectDepositCancelRequest(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
        _kassBridge.requestDepositCancel(l2TokenAddress, tokenId, amount, l2Recipient, nonce);

        // check if balance still the same
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), 0x0);

        // deposit cancel request
        expectDepositCancel(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
        _kassBridge.cancelDeposit(l2TokenAddress, tokenId, amount, l2Recipient, nonce);

        // check if balance was updated
        assertEq(_l1TokenInstance.balanceOf(sender, tokenId), amount);
    }

    function test_DepositCancel_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = uint256(keccak256("huge amount"));
        uint256 nonce = 0x0;

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
}
