// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./factory/KassERC721.sol";
import "./factory/KassERC1155.sol";
import "./factory/KassERC1967Proxy.sol";
import "./KassStorage.sol";

abstract contract TokenDeployer is KassStorage {

    function getL1TokenAddress(uint256 l2TokenAddress) public view returns (address) {
        return _state.wrappers[l2TokenAddress];
    }

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

    function setDeployerImplementations(
        address proxyImplementationAddress_,
        address erc721ImplementationAddress_,
        address erc1155ImplementationAddress_
    ) public virtual {
        require(Address.isContract(proxyImplementationAddress_), "Invalid Proxy implementation");
        require(KassUtils.isERC721(erc721ImplementationAddress_), "Invalid ERC 721 implementation");
        require(KassUtils.isERC1155(erc1155ImplementationAddress_), "Invalid ERC 1155 implementation");

        _state.proxyImplementationAddress = proxyImplementationAddress_;
        _state.erc721ImplementationAddress = erc721ImplementationAddress_;
        _state.erc1155ImplementationAddress = erc1155ImplementationAddress_;
    }

    //
    // Internals
    //

    /**
     * Modified https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol#L30
     * to support Create2.
     * @param l2TokenAddress Salt for CREATE2
     */
    function _cloneProxy(uint256 l2TokenAddress) private returns (address payable result) {
        bytes20 targetBytes = bytes20(_state.proxyImplementationAddress);
        bytes32 salt = bytes32(l2TokenAddress);

        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(0, clone, 0x37, salt)
        }

        _state.wrappers[l2TokenAddress] = result;
    }

    function _cloneKassERC1155(
        uint256 l2TokenAddress,
        bytes memory _calldata
    ) internal returns (address payable result) {
        result = _cloneProxy(l2TokenAddress);

        KassERC1967Proxy(result).initializeKassERC1967Proxy(
            _state.erc1155ImplementationAddress,
            abi.encodeWithSelector(KassERC1155.initialize.selector, _calldata)
        );
    }

    function _cloneKassERC721(
        uint256 l2TokenAddress,
        bytes memory _calldata
    ) internal returns (address payable result) {
        result = _cloneProxy(l2TokenAddress);

        KassERC1967Proxy(result).initializeKassERC1967Proxy(
            _state.erc721ImplementationAddress,
            abi.encodeWithSelector(KassERC721.initialize.selector, _calldata)
        );
    }
}
