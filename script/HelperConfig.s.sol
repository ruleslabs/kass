// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address starknetMessaging;
        uint256 l2KassAddress;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[11155111] = getGoerliEthConfig();
        chainIdToNetworkConfig[31337] = getMainnetEthConfig();

        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getGoerliEthConfig() internal pure returns (NetworkConfig memory goerliNetworkConfig) {
        goerliNetworkConfig = NetworkConfig({
            starknetMessaging: address(0xde29d060D45901Fb19ED6C6e959EB22d8626708e),
            l2KassAddress: 0x0
        });
    }

    function getMainnetEthConfig() internal pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            starknetMessaging: address(0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4),
            l2KassAddress: 0x0
        });
    }
}
