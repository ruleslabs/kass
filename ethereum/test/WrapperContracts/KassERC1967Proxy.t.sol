// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../src/factory/KassERC1967Proxy.sol";
import "../../src/factory/KassERC1155.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_KassERC1967Proxy is Test {
    KassERC1967Proxy public _kassERC1967Proxy = new KassERC1967Proxy();
    KassERC1155 public _kassERC1155 = new KassERC1155();

    function setUp() public {
        initializeProxy();
    }

    function initializeProxy() internal {
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC1155),
            abi.encodeWithSelector(KassERC1155.initialize.selector, abi.encode(""))
        );
    }
}

contract Test_KassERC1967Proxy is TestSetup_KassERC1967Proxy {

    function test_CannotInitializeTwice() public {
        // initialize proxy with a new implementation
        vm.expectRevert("Already initialized");
        initializeProxy();
    }
}
