// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/KassUtils.sol";
import "../src/factory/KassERC1155.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Withdraw is KassTestBase {
    KassERC721 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL);
        _l1TokenInstance = KassERC721(_kass.createL1Instance721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, L2_TOKEN_SYMBOL));
    }

    function _721_basicWithdrawTest(uint256 l2TokenAddress, uint256 tokenId, address l1Recipient) internal {
        // assert token does not exist on L1
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenInstance.ownerOf(tokenId);

        // deposit from L2 and withdraw to L1
        depositOnL1(l2TokenAddress, tokenId, 0x1, l1Recipient);
        expectWithdrawOnL1(l2TokenAddress, tokenId, 0x1, l1Recipient);
        _kass.withdraw721(l2TokenAddress, tokenId, l1Recipient);

        // assert token owner is l1Recipient
        assertEq(_l1TokenInstance.ownerOf(tokenId), l1Recipient);
    }
}

contract Test_721_Withdraw is TestSetup_721_Withdraw {

    function test_721_BasicWithdrawFromL2_1() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        _721_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, l1Recipient);
    }

    function test_721_BasicWithdrawFromL2_2() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = 0x2;

        _721_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, l1Recipient);
    }

    function test_721_BasicWithdrawFromL2_3() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 3"))));
        uint256 tokenId = 0x2 << UINT256_PART_SIZE_BITS;

        _721_basicWithdrawTest(L2_TOKEN_ADDRESS, tokenId, l1Recipient);
    }

    function test_CannotWithdrawFromL2WithDifferentTokenIdFromL2Request() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, 0x1, l1Recipient);

        vm.expectRevert();
        _kass.withdraw721(L2_TOKEN_ADDRESS, tokenId - 1, l1Recipient);
    }

    function test_CannotWithdrawFromL2WithDifferentL1RecipientFromL2Request() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        address fakeL1Recipient = address(uint160(uint256(keccak256("rando 2"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, 0x1, l1Recipient);

        vm.expectRevert();
        _kass.withdraw721(L2_TOKEN_ADDRESS, tokenId, fakeL1Recipient);
    }

    function test_CannotWithdrawFromL2Twice() public {
        address l1Recipient = address(uint160(uint256(keccak256("rando 1"))));
        uint256 tokenId = uint256(keccak256("token 1"));

        // deposit from L2
        depositOnL1(L2_TOKEN_ADDRESS, tokenId, 0x1, l1Recipient);

        // withdraw
        expectWithdrawOnL1(L2_TOKEN_ADDRESS, tokenId, 0x1, l1Recipient);
        _kass.withdraw721(L2_TOKEN_ADDRESS, tokenId, l1Recipient);

        vm.clearMockedCalls();
        vm.expectRevert();
        _kass.withdraw721(L2_TOKEN_ADDRESS, tokenId, l1Recipient);
    }
}
