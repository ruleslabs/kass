// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./ERC1155/KassERC1155.sol";

contract KassBridge is Ownable {
    address public baseToken;
    IStarknetMessaging private starknetMessaging;

    uint256 private l2KassAddress;

    // CONSTRUCTOR

    constructor(address _starknetMessaging) {
        baseToken = address(new KassERC1155{ salt: keccak256("V0.1") }());
        // This is the contract that will be cloned to all others
        // BridgedERC20(baseAccount).init(address(this), "STAB", "STAB");
        // This should be either configurable or changeable by some address

        starknetMessaging = IStarknetMessaging(_starknetMessaging);
    }

    // GETTERS

    function computeL1TokenAddress(uint256 l2TokenAddress) public view returns (address addr) {
        bytes20 baseAddressBytes = bytes20(baseToken);
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

    // SETTERS

    function setL2KassAddress(uint256 _l2KassAddress) public onlyOwner {
        l2KassAddress = _l2KassAddress;
    }

    // BUSINESS LOGIC

    function createL1Instance(uint256 l2TokenAddress, string[] calldata uri) public returns (address) {
        // compute L1 instance request payload
        uint256[] memory payload = new uint256[](uri.length + 1);

        // store L2 token address
        payload[0] = l2TokenAddress;

        // store token URI
        for (uint8 i = 0; i < uri.length; ++i) {
            payload[i + 1] = KassUtils.strToUint256(uri[i]);
        }

        // consume L1 instance request message
        starknetMessaging.consumeMessageFromL2(l2KassAddress, payload);

        // deploy Kass ERC1155 and set URI
        address l1TokenAddress = cloneKassERC1155(bytes32(l2TokenAddress));
        KassERC1155(l1TokenAddress).setURI(KassUtils.concat(uri));

        return l1TokenAddress;
    }

    // INTERNALS

    /**
     * Modified https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol#L30
     * to support Create2.
     * @param _salt Salt for CREATE2
     */
    function cloneKassERC1155(bytes32 _salt) internal returns (address payable result) {
        bytes20 targetBytes = bytes20(baseToken);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(0, clone, 0x37, _salt)
        }
        return result;
    }
}
