// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./factory/KassERC721.sol";
import "./factory/KassERC1155.sol";
import "./factory/KassERC1967Proxy.sol";
import "./KassStorage.sol";

abstract contract TokenDeployer is KassStorage {
    // CONSTRUCTOR

    function setDeployerImplementations() internal {
        if (_state.proxyImplementationAddress == address(0x0)) {
            _state.proxyImplementationAddress = address(
                new KassERC1967Proxy{ salt: keccak256("KassERC1967Proxy") }()
            );
        }

        if (_state.erc721ImplementationAddress == address(0x0)) {
            _state.erc721ImplementationAddress = address(
                new KassERC721{ salt: keccak256("KassERC721") }()
            );
        }

        if (_state.erc1155ImplementationAddress == address(0x0)) {
            _state.erc1155ImplementationAddress = address(
                new KassERC1155{ salt: keccak256("KassERC1155") }()
            );
        }
    }

    // GETTERS

    function computeL1TokenAddress(uint256 l2TokenAddress) public view returns (address addr) {
        bytes20 baseAddressBytes = bytes20(_state.proxyImplementationAddress);
        bytes20 deployerBytes = bytes20(address(this));

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), baseAddressBytes)
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

            let bytecodeHash := keccak256(ptr, 0x37)

            mstore(ptr, 0xff00000000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x1), deployerBytes)
            mstore(add(ptr, 0x15), l2TokenAddress)
            mstore(add(ptr, 0x35), bytecodeHash)

            addr := keccak256(ptr, 0x55)
        }
    }

    // INTERNALS

    /**
     * Modified https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol#L30
     * to support Create2.
     * @param salt Salt for CREATE2
     */
    function cloneProxy(bytes32 salt) private returns (address payable result) {
        bytes20 targetBytes = bytes20(_state.proxyImplementationAddress);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(0, clone, 0x37, salt)
        }
    }

    function cloneKassERC1155(bytes32 salt, bytes memory _calldata) internal returns (address payable result) {
        result = cloneProxy(salt);

        KassERC1967Proxy(result).initializeKassERC1967Proxy(
            _state.erc1155ImplementationAddress,
            abi.encodeWithSelector(KassERC1155.initialize.selector, _calldata)
        );
    }

    function cloneKassERC721(bytes32 salt, bytes memory _calldata) internal returns (address payable result) {
        result = cloneProxy(salt);

        KassERC1967Proxy(result).initializeKassERC1967Proxy(
            _state.erc721ImplementationAddress,
            abi.encodeWithSelector(KassERC721.initialize.selector, _calldata)
        );
    }
}
