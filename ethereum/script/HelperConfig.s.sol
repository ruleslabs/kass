// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address starknetMessaging;
        uint256 l2KassAddress;
        address proxyAddress;
        address proxyImplementationAddress;
        address erc721ImplementationAddress;
        address erc1155ImplementationAddress;
    }

    mapping(uint256 chainId => NetworkConfig networkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[1] = getMainnetEthConfig();
        chainIdToNetworkConfig[5] = getGoerliEthConfig();

        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getGoerliEthConfig() internal pure returns (NetworkConfig memory goerliNetworkConfig) {
        goerliNetworkConfig = NetworkConfig({
            starknetMessaging: address(0xde29d060D45901Fb19ED6C6e959EB22d8626708e),
            l2KassAddress: 0x0,
            proxyAddress: address(0x0),
            proxyImplementationAddress: address(0x8525cDD421a4F2905551C084211da64fa811Cc41),
            erc721ImplementationAddress: address(0x1b2FBc7DBa063A268f8604BdE0461c80A5DE14f3),
            erc1155ImplementationAddress: address(0x8A178b67b40b5B8C9CebBB22d62272A7A037853B)
        });
    }

    function getMainnetEthConfig() internal pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            starknetMessaging: address(0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4),
            l2KassAddress: 0x0,
            proxyAddress: address(0x0),
            proxyImplementationAddress: address(0x0),
            erc721ImplementationAddress: address(0x0),
            erc1155ImplementationAddress: address(0x0)
        });
    }
}
