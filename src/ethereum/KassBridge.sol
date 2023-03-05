// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./ERC1155/KassERC1155.sol";
import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./KassDeployer.sol";
import "./StarknetConstants.sol";
import "./KassMessagingPayloads.sol";

contract KassBridge is Ownable, KassDeployer, KassMessagingPayloads {
    IStarknetMessaging private _starknetMessaging;

    uint256 private _l2KassAddress;

    // CONSTRUCTOR

    constructor(address starknetMessaging_) Ownable() KassDeployer() {
        _starknetMessaging = IStarknetMessaging(starknetMessaging_);
    }

    // GETTERS

    function l2KassAddress() public view returns (uint256) {
        return _l2KassAddress;
    }

    // SETTERS

    function setL2KassAddress(uint256 l2KassAddress_) public onlyOwner {
        _l2KassAddress = l2KassAddress_;
    }

    // BUSINESS LOGIC

    function createL1Instance(uint256 l2TokenAddress, string[] calldata uri) public returns (address) {
        // compute L1 instance request payload
        uint256[] memory payload = instanceCreationMessagePayload(l2TokenAddress, uri);

        // consume L1 instance request message
        _starknetMessaging.consumeMessageFromL2(_l2KassAddress, payload);

        // deploy Kass ERC1155 and set URI
        address l1TokenAddress = cloneKassERC1155(bytes32(l2TokenAddress));
        KassERC1155(l1TokenAddress).init(KassUtils.concat(uri));

        return l1TokenAddress;
    }

    function withdraw(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) public {
        require(amount > 0, "Cannot withdraw null amount");

        // compute L1 instance request payload
        uint256[] memory payload = tokenDepositFromL2MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient);

        // consume L1 withdraw request message
        _starknetMessaging.consumeMessageFromL2(_l2KassAddress, payload);

        // get l1 token instance
        KassERC1155 l1TokenInstance = KassERC1155(computeL1TokenAddress(l2TokenAddress));

        // mint tokens
        l1TokenInstance.mint(l1Recipient, tokenId, amount);
    }

    function deposit(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, uint256 l2Recipient) public {
        require(amount > 0, "Cannot deposit null amount");

        // get l1 token instance
        KassERC1155 l1TokenInstance = KassERC1155(computeL1TokenAddress(l2TokenAddress));

        // burn tokens
        l1TokenInstance.burn(msg.sender, tokenId, amount);

        // compute L2 deposit payload and sent it
        uint256[] memory payload = tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient);
        _starknetMessaging.sendMessageToL2(_l2KassAddress, DEPOSIT_HANDLER_SELECTOR, payload);
    }
}
