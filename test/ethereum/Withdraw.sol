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

    function testWithdrawFromL2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 amount = 0x10;

        // deposit from L2
        depositFromL2(L2_TOKEN_ADDRESS, tokenId, amount, l1Recipient);

        // assert balance is empty
        assertEq(_l1TokenInstance.balanceOf(l1Recipient, tokenId), 0);

        // with deposited tokens
        withdrawFromL2(tokenId, amount, l1Recipient);

        // assert balance was updated
        assertEq(_l1TokenInstance.balanceOf(l1Recipient, tokenId), amount);
    }
}
