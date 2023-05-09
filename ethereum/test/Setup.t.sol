// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./KassTestBase.sol";
import "../src/Kass.sol";

// solhint-disable contract-name-camelcase

contract Test_Setup is KassTestBase {

    function test_UpdateL2KassAddress() public {
        _kass.setL2KassAddress(0xdead);
        assertEq(_kass.l2KassAddress(), 0xdead);
    }

    function test_CannotUpdateL2KassAddressIfNotOwner() public {
        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        _kass.setL2KassAddress(0xdead);
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert("Already initialized");
        _kass.initialize(abi.encodeWithSelector(Kass.initialize.selector, abi.encode(uint256(0x0), address(0x0))));
    }

    function test_UpgradeImplementation() public {
        address newImplementation = address(new Kass());

        assertEq(_kass.l2KassAddress(), L2_KASS_ADDRESS);

        _kass.upgradeToAndCall(
            newImplementation,
            abi.encodeWithSelector(
                Kass.initialize.selector,
                abi.encode(
                    uint256(0x0),
                    address(0x0),
                    address(0x0),
                    address(0x0),
                    address(0x0)
                )
            )
        );

        assertEq(_kass.l2KassAddress(), 0x0);
    }

    function test_CannotUpgradeImplementationIfNotOwner() public {
        address newImplementation = address(new Kass());

        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        _kass.upgradeToAndCall(
            newImplementation,
            abi.encodeWithSelector(Kass.initialize.selector, abi.encode(uint256(0x0), address(0x0)))
        );
    }

    function test_CannotUpgradeToInvalidImplementation() public {
        vm.expectRevert();
        _kass.upgradeTo(address(0xdead));
    }
}
