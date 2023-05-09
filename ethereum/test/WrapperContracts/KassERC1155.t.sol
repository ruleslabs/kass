// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/factory/KassERC1155.sol";
import "../../src/factory/KassERC1967Proxy.sol";
import "../../src/KassUtils.sol";
import "../../src/mocks/UpgradedContractMock.sol";
import "../KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_KassERC1155 is KassTestBase {
    KassERC1155 public _kassERC1155 = new KassERC1155();
    KassERC1967Proxy public _kassERC1967Proxy = new KassERC1967Proxy();
    UpgradedContractMock public _upgradedContractMock = new UpgradedContractMock();

    function setUp() public override {
        _kassERC1155.initialize(abi.encode(KassUtils.felt252WordsToStr(L2_TOKEN_URI)));
        _kassERC1967Proxy.initializeKassERC1967Proxy(
            address(_kassERC1155),
            abi.encodeWithSelector(KassERC1155.initialize.selector, abi.encode(""))
        );
    }
}

contract Test_KassERC1155 is TestSetup_KassERC1155 {

    function test_1155_Upgrade() public {
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
        assertEq(UpgradedContractMock(address(_kassERC1967Proxy)).foo(), _upgradedContractMock.foo());
    }

    function test_1155_CannotUpgradeIfNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        KassERC1155(address(_kassERC1967Proxy)).upgradeTo(address(_upgradedContractMock));
    }

    function test_1155_CannotInitializeTwice() public {
        // create L1 wrapper
        vm.expectRevert("Kass1155: Already initialized");
        _kassERC1155.initialize(abi.encode("bar"));
        assertEq(_kassERC1155.uri(0), string(KassUtils.felt252WordsToStr(L2_TOKEN_URI)));
    }

    function test_1155_CannotMintIfNotDeployer() public {
        vm.prank(address(0x1));
        vm.expectRevert("Kass1155: Not deployer");
        _kassERC1155.permissionedMint(address(0x1), 0x1, 0x1);
    }
}
