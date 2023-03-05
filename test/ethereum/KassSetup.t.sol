// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./KassTestBase.sol";

contract KassSetupTest is KassTestBase {

    function testUpdateL2KassAddress() public {
        _kassBridge.setL2KassAddress(0xdead);
        assertEq(_kassBridge.l2KassAddress(), 0xdead);
    }

    function testCannotUpdateL2KassAddressIfNotOwner() public {
        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        _kassBridge.setL2KassAddress(0xdead);
    }
}
