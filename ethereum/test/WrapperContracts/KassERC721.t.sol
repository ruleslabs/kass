// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/factory/KassERC721.sol";
import "../../src/factory/KassERC1967Proxy.sol";
import "../../src/mocks/UpgradedContractMock.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_KassERC721 is KassTestBase {
    KassERC721 public _kassERC721 = new KassERC721();
    KassERC1967Proxy public _kassERC1967Proxy = new KassERC1967Proxy();
    UpgradedContractMock public _upgradedContractMock = new UpgradedContractMock();

    function setUp() public override {
        _kassERC721.initialize(abi.encode(L2_TOKEN_NAME, L2_TOKEN_SYMBOL));
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC721),
            abi.encodeWithSelector(KassERC721.initialize.selector, abi.encode(""))
        );
    }
}

contract Test_KassERC721 is TestSetup_KassERC721 {

    function test_721_Upgrade() public {
        KassERC721(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
        assertEq(UpgradedContractMock(address(_kassERC1967Proxy)).foo(), _upgradedContractMock.foo());
    }

    function test_721_CannotUpgradeIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        KassERC721(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
    }

    function test_721_CannotInitializeTwice() public {
        // create L1 wrapper
        vm.expectRevert("Kass721: Already initialized");
        _kassERC721.initialize(abi.encode("bar", "bar"));
        assertEq(_kassERC721.name(), L2_TOKEN_NAME);
        assertEq(_kassERC721.symbol(), L2_TOKEN_SYMBOL);
    }

    function test_721_CannotMintIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass721: Not deployer");
        _kassERC721.permissionedMint(address(0x1), 0x1);
    }
}
