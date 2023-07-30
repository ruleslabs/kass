// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/factory/ERC1155.sol";
import "../src/factory/ERC1967Proxy.sol";
import "../src/Utils.sol";

import "./mocks/UpgradedContractMock.sol";
import "./utils/Constants.sol";

// solhint-disable contract-name-camelcase

contract TestKassERC721 is Test {

    //
    // Storage
    //

    KassERC721 _kassERC721 = new KassERC721();
    KassERC1967Proxy _kassERC1967Proxy = new KassERC1967Proxy();
    UpgradedContractMock _upgradedContractMock = new UpgradedContractMock();

    //
    // Setup
    //

    function setUp() public {
        _kassERC721.initialize(abi.encode(Constants.L2_TOKEN_NAME(), Constants.L2_TOKEN_SYMBOL()));
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC721),
            abi.encodeWithSelector(KassERC721.initialize.selector, abi.encode(""))
        );
    }

    //
    // Tests
    //

    function testERC721Upgrade() public {
        KassERC721(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
        assertEq(UpgradedContractMock(address(_kassERC1967Proxy)).foo(), _upgradedContractMock.foo());
    }

    function testERC721CannotUpgradeIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        KassERC721(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
    }

    function testERC721CannotInitializeTwice() public {
        // create L1 wrapper
        vm.expectRevert("Kass721: Already initialized");
        _kassERC721.initialize(abi.encode("bar", "bar"));
        assertEq(_kassERC721.name(), Constants.L2_TOKEN_NAME());
        assertEq(_kassERC721.symbol(), Constants.L2_TOKEN_SYMBOL());
    }

    function testERC721CannotMintIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass721: Not bridge");
        _kassERC721.permissionedMint(address(0x1), 0x1);
    }

    function testERC721CannotBurnIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass721: Not bridge");
        _kassERC721.permissionedBurn(0x1);
    }

    function testERC721CannotUpgradeIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass721: Not bridge");
        _kassERC721.permissionedUpgradeTo(address(_upgradedContractMock));
    }
}
