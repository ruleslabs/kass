// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/factory/ERC1967Proxy.sol";
import "../src/factory/ERC1155.sol";

contract TestKassERC1967Proxy is Test {

    //
    // Constructor
    //

    KassERC1967Proxy _kassERC1967Proxy = new KassERC1967Proxy();
    KassERC1155 _kassERC1155 = new KassERC1155();

    //
    // Setup
    //

    function setUp() public {
        _initializeProxy();
    }

    function _initializeProxy() internal {
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC1155),
            abi.encodeWithSelector(KassERC1155.initialize.selector, abi.encode(""))
        );
    }

    //
    // Tests
    //

    function testCannotInitializeTwice() public {
        // initialize proxy with a new implementation
        vm.expectRevert("Already initialized");
        _initializeProxy();
    }
}
