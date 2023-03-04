// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./ERC1155/KassERC1155.sol";

contract KassBridge is Ownable {
    IStarknetMessaging private starknetMessaging;

    uint256 private l2KassAddress;

    // CONSTRUCTOR

    constructor(address _starknetMessaging) {
        starknetMessaging = IStarknetMessaging(_starknetMessaging);
    }

    // GETTERS

    function l1TokenAddress(uint256 l2TokenAddress) public view returns (address) {
        return KassUtils.computeAddress(address(this), type(KassERC1155).creationCode, bytes32(l2TokenAddress));
    }

    // SETTERS

    function setL2KassAddress(uint256 _l2KassAddress) public onlyOwner {
        l2KassAddress = _l2KassAddress;
    }

    // BUSINESS LOGIC

    function createL1Instance(uint256 l2TokenAddress, string[] calldata uri) public returns (address) {
        // compute L1 instance request payload
        uint256[] memory payload = new uint256[](uri.length + 1);

        // load L2 token address
        payload[0] = l2TokenAddress;

        for (uint8 i = 0; i < uri.length; ++i) {
            payload[i + 1] = KassUtils.strToUint256(uri[i]);
        }

        // consume L1 instance request message
        starknetMessaging.consumeMessageFromL2(l2KassAddress, payload);

        // deploy Kass ERC1155 and set URI
        KassERC1155 l1TokenInstance = new KassERC1155{salt: bytes32(l2TokenAddress)}();
        l1TokenInstance.setURI(KassUtils.concat(uri));

        return address(l1TokenInstance);
    }
}
