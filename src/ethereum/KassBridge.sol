// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/utils/Context.sol";

import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./ERC1155/KassERC1155.sol";

contract KassBridge is Context {
    IStarknetMessaging private starknetMessaging;

    // CONSTRUCTOR

    constructor(address _starknetMessaging) {
        starknetMessaging = IStarknetMessaging(_starknetMessaging);
    }

    // GETTERS

    function l1Address(uint256 l2TokenAddress) public view returns (address) {
        return KassUtils.computeAddress(address(this), type(KassERC1155).creationCode, bytes32(l2TokenAddress));
    }

    // BUSINESS LOGIC

    function createL1Instance(uint256 tokenL2Address, string[] calldata uri) public returns (address) {
        // compute L1 instance request payload
        uint256[] memory payload = new uint256[](uri.length);
        for (uint8 i = 0; i < uri.length; ++i) {
            payload[i] = KassUtils.strToUint256(uri[i]);
        }

        // consume L1 instance request message
        starknetMessaging.consumeMessageFromL2(tokenL2Address, payload);

        // deploy Kass ERC1155 and set URI
        KassERC1155 l1TokenInstance = new KassERC1155{salt: bytes32(tokenL2Address)}();
        l1TokenInstance.setURI(KassUtils.concat(uri));

        return address(l1TokenInstance);
    }
}
