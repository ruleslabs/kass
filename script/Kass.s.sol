// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./HelperConfig.s.sol";

import "../src/ethereum/Kass.sol";

contract DeployKass is Script {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        HelperConfig helperConfig = new HelperConfig();

        (address starknetMessagingAddress, uint256 l2KassAddress) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();

        // deploy implementation
        address implementationAddress = address(new Kass());

        // deploy proxy
        new ERC1967Proxy(
            implementationAddress,
            abi.encodeWithSelector(Kass.initialize.selector, abi.encode(l2KassAddress, starknetMessagingAddress))
        );

        vm.stopBroadcast();
    }
}
