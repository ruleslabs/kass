// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./ERC1155/KassERC1155.sol";

abstract contract KassDeployer {
    address public _baseToken;

    // CONSTRUCTOR

    constructor() {
        // This is the contract that will be cloned to all others
        _baseToken = address(new KassERC1155{ salt: keccak256("V0.1") }());
    }

    // GETTERS

    function computeL1TokenAddress(uint256 l2TokenAddress) public view returns (address addr) {
        bytes20 baseAddressBytes = bytes20(_baseToken);
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
    function cloneKassERC1155(bytes32 salt) internal returns (address payable result) {
        bytes20 targetBytes = bytes20(_baseToken);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(0, clone, 0x37, salt)
        }
        return result;
    }
}
