// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../../src/KassUtils.sol";
import "../../src/factory/KassERC721.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_Wrapped_Deposit is KassTestBase, ERC721Holder {
    KassERC721 public _l1NativeToken;
    address public _tokenOwner = address(uint160(uint256(keccak256("owner"))));

    function _bytes32_l1NativeToken() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(_l1NativeToken))));
    }

    function _721_mintTokens(address to, uint256 tokenId) internal {
        // mint tokens
        vm.prank(_tokenOwner);
        _l1NativeToken.mint(to, tokenId);
    }

    function setUp() public override {
        super.setUp();

        vm.startPrank(_tokenOwner);
        _l1NativeToken = new KassERC721();
        _l1NativeToken.initialize(abi.encode(L2_TOKEN_NAME, L2_TOKEN_SYMBOL));
        vm.stopPrank();
    }
}

contract Test_721_Wrapped_Deposit is TestSetup_721_Wrapped_Deposit {

    function test_721_wrapped_DepositToL2_1() public {
        address sender = address(this);
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));

        // mint Token
        _721_mintTokens(sender, tokenId);

        // approve kass operator
        _l1NativeToken.approve(address(_kass), tokenId);

        // assert token owner is sender
        assertEq(_l1NativeToken.ownerOf(tokenId), sender);

        expectDepositOnL2(_bytes32_l1NativeToken(), sender, l2Recipient, tokenId, 0x1, 0x0);
        _kass.deposit(_bytes32_l1NativeToken(), l2Recipient, tokenId);

        // assert token has been transfered to Kass
        assertEq(_l1NativeToken.ownerOf(tokenId), address(_kass));
    }

    function test_721_wrapped_CannotDepositToL2IfNotTokenOwner() public {
        uint256 l2Recipient = uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME;
        uint256 tokenId = uint256(keccak256("token 1"));
        address l1Rando1 = address(uint160(uint256(keccak256("rando 1"))));

        // mint Token
        _721_mintTokens(l1Rando1, tokenId);

        // try deposit on L2
        vm.expectRevert("ERC721: caller is not token owner or approved");
        _kass.deposit(_bytes32_l1NativeToken(), l2Recipient, tokenId);

        // approve kass operator
        vm.prank(l1Rando1);
        _l1NativeToken.approve(address(_kass), tokenId);

        // try deposit on L2
        vm.expectRevert("ERC721: transfer from incorrect owner");
        _kass.deposit(_bytes32_l1NativeToken(), l2Recipient, tokenId);
    }
}
