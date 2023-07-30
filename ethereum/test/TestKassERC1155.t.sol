// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/factory/ERC1155.sol";
import "../src/factory/ERC1967Proxy.sol";
import "../src/Utils.sol";

import "./mocks/UpgradedContractMock.sol";
import "./utils/Constants.sol";

contract TestKassERC1155 is Test {

    //
    // Storage
    //

    KassERC1155 _kassERC1155 = new KassERC1155();
    KassERC1967Proxy _kassERC1967Proxy = new KassERC1967Proxy();
    UpgradedContractMock _upgradedContractMock = new UpgradedContractMock();

    //
    // Setup
    //

    function setUp() public {
        _kassERC1155.initialize(abi.encode(Constants.L2_TOKEN_FLAT_URI()));
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC1155),
            abi.encodeWithSelector(KassERC1155.initialize.selector, abi.encode(""))
        );
    }

    //
    // Tests
    //

    function testERC1155Upgrade() public {
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
        assertEq(UpgradedContractMock(address(_kassERC1967Proxy)).foo(), _upgradedContractMock.foo());
    }

    function testERC1155CannotUpgradeIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
    }

    function testERC1155CannotInitializeTwice() public {
        // create L1 wrapper
        vm.expectRevert("Kass1155: Already initialized");
        _kassERC1155.initialize(abi.encode("bar"));

        assertEq(_kassERC1155.uri(0), Constants.L2_TOKEN_FLAT_URI());
    }

    function testERC1155CannotMintIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass1155: Not bridge");
        _kassERC1155.permissionedMint(address(0x1), 0x1, 0x1);
    }

    function testERC1155CannotBurnIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass1155: Not bridge");
        _kassERC1155.permissionedBurn(address(0x1), 0x1, 0x1);
    }

    function testERC1155CannotUpgradeIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass1155: Not bridge");
        _kassERC1155.permissionedUpgradeTo(address(_upgradedContractMock));
    }
}
