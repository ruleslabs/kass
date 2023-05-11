// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./HelperConfig.s.sol";

import "../src/Kass.sol";
import "../src/factory/KassERC721.sol";
import "../src/factory/KassERC1155.sol";
import "../src/factory/KassERC1967Proxy.sol";

contract DeployKass is Script {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    event Test(address a, address b);

    function run() public {
        HelperConfig helperConfig = new HelperConfig();

        (
            address deployer,
            address starknetMessagingAddress,
            uint256 l2KassAddress,
            address proxyAddress,
            address proxyImplementationAddress,
            address erc721ImplementationAddress,
            address erc1155ImplementationAddress
        ) = helperConfig.activeNetworkConfig();

        require(deployer != address(0x0), "Deployer address cannot be null");

        address computedProxyImplementationAddress = computeCreate2Address(
            keccak256("KassERC1967Proxy"),
            hashInitCode(type(KassERC1967Proxy).creationCode),
            deployer
        );

        address computedERC721ImplementationAddress = computeCreate2Address(
            keccak256("KassERC721"),
            hashInitCode(type(KassERC721).creationCode),
            deployer
        );

        address computedERC1155ImplementationAddress = computeCreate2Address(
            keccak256("KassERC1155"),
            hashInitCode(type(KassERC1155).creationCode),
            deployer
        );

        vm.startBroadcast();

        // deploy implementations
        address implementationAddress = address(new Kass());

        if (proxyImplementationAddress != computedProxyImplementationAddress) {
            proxyImplementationAddress = address(new KassERC1967Proxy{ salt: keccak256("KassERC1967Proxy") }());
        }

        if (erc721ImplementationAddress != computedERC721ImplementationAddress) {
            erc721ImplementationAddress = address(new KassERC721{ salt: keccak256("KassERC721") }());
        }

        if (erc1155ImplementationAddress != computedERC1155ImplementationAddress) {
            erc1155ImplementationAddress = address(new KassERC1155{ salt: keccak256("KassERC1155") }());
        }

        // deploy proxy
        if (proxyAddress == address(0x0))
            new ERC1967Proxy{ salt: keccak256("Kass") }(
                implementationAddress,
                abi.encodeWithSelector(
                    Kass.initialize.selector,
                    abi.encode(
                        l2KassAddress,
                        starknetMessagingAddress,
                        proxyImplementationAddress,
                        erc721ImplementationAddress,
                        erc1155ImplementationAddress
                    )
                )
            );
        else {
            Kass(payable(proxyAddress)).upgradeToAndCall(
                implementationAddress,
                abi.encodeWithSelector(
                    Kass.initialize.selector,
                    abi.encode(
                        l2KassAddress,
                        starknetMessagingAddress,
                        proxyImplementationAddress,
                        erc721ImplementationAddress,
                        erc1155ImplementationAddress
                    )
                )
            );
        }

        vm.stopBroadcast();
    }
}
