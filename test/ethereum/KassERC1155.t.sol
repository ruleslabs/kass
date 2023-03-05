// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../src/ethereum/ERC1155/KassERC1155.sol";
import "../../src/ethereum/KassUtils.sol";

contract KassERC1155Test is Test {
    KassERC1155 public _kassERC1155 = new KassERC1155();

    function setUp() public {
        _kassERC1155.init("foo");
    }

    function testCannotInitL1TokenInstanceTwice() public {
        // create L1 instance
        vm.expectRevert("Can only init once");
        _kassERC1155.init("bar");
        assertEq(_kassERC1155.uri(0), "foo");
    }

    function testCannotUpdateL1TokenInstanceUriIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Caller is not the deployer");
        _kassERC1155.setURI("foo");
    }

    function testUpdateL1TokenInstanceUri() public {
        _kassERC1155.setURI("bar");
        assertEq(_kassERC1155.uri(0), "bar");
    }
}
