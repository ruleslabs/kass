// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/factory/KassERC1155.sol";
import "../src/factory/KassERC1967Proxy.sol";
import "../src/KassUtils.sol";
import "../src/mocks/UpgradedContractMock.sol";

contract KassERC1155Test is Test {
    KassERC1155 public _kassERC1155 = new KassERC1155();
    KassERC1967Proxy public _kassERC1967Proxy = new KassERC1967Proxy();
    UpgradedContractMock public _upgradedContractMock = new UpgradedContractMock();

    function setUp() public {
        _kassERC1155.initialize(abi.encode("foo"));
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC1155),
            abi.encodeWithSelector(KassERC1155.initialize.selector, abi.encode(""))
        );
    }

    function test_Upgrade() public {
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
        assertEq(UpgradedContractMock(address(_kassERC1967Proxy)).foo(), _upgradedContractMock.foo());
    }

    function test_CannotUpgradeIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
    }

    function test_CannotInitializeTwice() public {
        // create L1 instance
        vm.expectRevert("Kass1155: Already initialized");
        _kassERC1155.initialize(abi.encode("bar"));
        assertEq(_kassERC1155.uri(0), "foo");
    }

    function test_CannotMintIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass1155: Not deployer");
        _kassERC1155.mint(address(0x1), 0x1, 0x1);
    }
}
