// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/factory/KassERC1155.sol";
import "../src/KassUtils.sol";

contract KassERC1155Test is Test {
    KassERC1155 public _kassERC1155 = new KassERC1155();

    function setUp() public {
        _kassERC1155.initialize(abi.encode("foo"));
    }

    function test_CannotInitializeTwice() public {
        // create L1 instance
        vm.expectRevert("Already initialized");
        _kassERC1155.initialize(abi.encode("bar"));
        assertEq(_kassERC1155.uri(0), "foo");
    }

    function test_CannotMintIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        _kassERC1155.mint(address(0x1), 0x1, 0x1);
    }
}
