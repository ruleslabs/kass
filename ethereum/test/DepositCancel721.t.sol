// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../src/KassUtils.sol";
import "../src/factory/KassERC721.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_DepositCancel is KassTestBase, ERC721Holder {
    KassERC721 public _l1TokenInstance;

    function setUp() public override {
        super.setUp();

        // request and create L1 instance
        requestL1InstanceCreation(L2_TOKEN_ADDRESS, L2_TOKEN_NAME_AND_SYMBOL);
        _l1TokenInstance = KassERC721(_kass.createL1Instance721(L2_TOKEN_ADDRESS, L2_TOKEN_NAME, L2_TOKEN_SYMBOL));
    }

    function _721_mintAndDepositBackOnL2(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 l2Recipient,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // mint tokens
        vm.prank(address(_kass));
        _l1TokenInstance.mint(sender, tokenId);

        // deposit tokens on L2
        expectDepositOnL2(sender, l2TokenAddress, tokenId, 0x1, l2Recipient, nonce);
        _kass.deposit721(l2TokenAddress, tokenId, l2Recipient);

        // check if there's no owner
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenInstance.ownerOf(tokenId);
    }

    function _721_basicDepositCancelTest(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 l2Recipient,
        uint256 nonce
    ) internal {
        address sender = address(this);

        // deposit on L1 and send back to L2
        _721_mintAndDepositBackOnL2(l2TokenAddress, tokenId, l2Recipient, nonce);

        // deposit cancel request
        expectDepositCancelRequest(sender, l2TokenAddress, tokenId, 0x1, l2Recipient, nonce);
        _kass.requestDepositCancel721(l2TokenAddress, tokenId, l2Recipient, nonce);

        // check if there's still no owner
        vm.expectRevert("ERC721: invalid token ID");
        _l1TokenInstance.ownerOf(tokenId);

        // deposit cancel request
        expectDepositCancel(sender, l2TokenAddress, tokenId, 0x1, l2Recipient, nonce);
        _kass.cancelDeposit721(l2TokenAddress, tokenId, l2Recipient, nonce);

        // check if owner is correct
        assertEq(_l1TokenInstance.ownerOf(tokenId), sender);
    }
}

contract Test_721_DepositCancel is TestSetup_721_DepositCancel {

    function test_721_DepositCancel_1() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = uint256(keccak256("huge nonce"));

        _721_basicDepositCancelTest(L2_TOKEN_ADDRESS, tokenId, l2Recipient, nonce);
    }

    function test_721_DepositCancel_2() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_basicDepositCancelTest(L2_TOKEN_ADDRESS, tokenId, l2Recipient, nonce);
    }

    function test_721_CannotRequestDepositCancelForAnotherDepositor() public {
        address fakeSender = address(uint160(uint256(keccak256("rando 1"))));
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        _721_mintAndDepositBackOnL2(L2_TOKEN_ADDRESS, tokenId, l2Recipient, nonce);

        vm.startPrank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kass.requestDepositCancel721(L2_TOKEN_ADDRESS, tokenId, l2Recipient, nonce);
    }

    function test_721_CannotRequestDepositCancelForUnknownDeposit() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        uint256 nonce = 0x0;

        vm.expectRevert("Deposit not found");
        _kass.cancelDeposit721(L2_TOKEN_ADDRESS, tokenId, l2Recipient, nonce);
    }
}
