// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./factory/KassERC721.sol";
import "./factory/KassERC1155.sol";
import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./TokenDeployer.sol";
import "./StarknetConstants.sol";
import "./KassMessagingPayloads.sol";
import "./KassStorage.sol";

contract Kass is Ownable, KassStorage, TokenDeployer, KassMessagingPayloads, UUPSUpgradeable {

    // EVENTS

    // L1 token address can be computed offchain from L2 token address
    // it does not need to be indexed
    event LogL1WrapperCreated(bytes32 indexed l2TokenAddress, address l1TokenAddress);
    event LogL2WrapperRequested(address indexed l1TokenAddress);

    event LogL1OwnershipClaimed(
        uint256 indexed l2TokenAddress,
        address l1TokenAddress,
        address l1Owner
    );
    event LogL2OwnershipClaimed(
        address indexed l1TokenAddress,
        uint256 l2Owner
    );

    event LogDeposit(
        address indexed sender,
        uint256 indexed l2TokenAddress,
        address l1TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed l2Recipient
    );
    event LogWithdrawal(
        uint256 indexed l2TokenAddress,
        address l1TokenAddress,
        uint256 tokenId,
        uint256 amount,
        address indexed l1Recipient
    );

    event LogDepositCancelRequest(
        address indexed sender,
        uint256 indexed l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed l2Recipient,
        uint256 nonce
    );
    event LogDepositCancel(
        address indexed sender,
        uint256 indexed l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed l2Recipient,
        uint256 nonce
    );

    // MODIFIERS

    modifier initializer() {
        address implementation = _getImplementation();

        require(!isInitialized(implementation), "Already initialized");

        setInitialized(implementation);

        _;
    }

    modifier onlyDepositor(uint256 nonce) {
        address depositor_ = _state.depositors[nonce];

        require(depositor_ != address(0x0), "Deposit not found");
        require(depositor_ == _msgSender(), "Caller is not the depositor");

        _;
    }

    // INIT

    function initialize(bytes calldata data) public initializer {
        (uint256 l2KassAddress_, IStarknetMessaging starknetMessaging_) = abi.decode(
            data,
            (uint256, IStarknetMessaging)
        );
        _state.l2KassAddress = l2KassAddress_;
        _state.starknetMessaging = starknetMessaging_;

        setDeployerImplementations();

        _transferOwnership(_msgSender());
    }

    // UPGRADE

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    // GETTERS

    function l2KassAddress() public view returns (uint256) {
        return _state.l2KassAddress;
    }

    function isInitialized(address implementation) private view returns (bool) {
        return _state.initializedImplementations[implementation];
    }

    // SETTERS

    function setL2KassAddress(uint256 l2KassAddress_) public onlyOwner {
        _state.l2KassAddress = l2KassAddress_;
    }

    function setInitialized(address implementation) private {
        _state.initializedImplementations[implementation] = true;
    }

    // INSTANCE CREATION

    function createL1Wrapper(uint256[] calldata messagePayload) public returns (address l1TokenAddress) {
        // consume L1 instance request message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, messagePayload);

        // parse message payload
        WrapperRequest memory wrapperRequest = parseWrapperRequestMessagePayload(messagePayload);

        // deploy Kass ERC1155 with URI
        if (wrapperRequest.tokenStandard == TokenStandard.ERC721) {
            l1TokenAddress = cloneKassERC721(wrapperRequest.tokenAddress, wrapperRequest._calldata);
        } else if (wrapperRequest.tokenStandard == TokenStandard.ERC1155) {
            l1TokenAddress = cloneKassERC1155(wrapperRequest.tokenAddress, wrapperRequest._calldata);
        } else {
            revert("Kass: Unkown token standard");
        }

        // emit event
        emit LogL1WrapperCreated(wrapperRequest.tokenAddress, l1TokenAddress);
    }

    // INSTANCE CREATION REQUEST

    function requestL2Wrapper(address tokenAddress) public {
        // compute l2 Wrapper Creation message payload and send it
        (uint256[] memory payload, uint256 handlerSelector) = computeL2WrapperCreationMessagePayload(tokenAddress);
        _state.starknetMessaging.sendMessageToL2(_state.l2KassAddress, handlerSelector, payload);

        // emit event
        emit LogL2WrapperRequested(tokenAddress);
    }

    // OWNERSHIP CLAIM

    function claimL1Ownership(uint256 l2TokenAddress) public {
        // compute ownership claim payload
        uint256[] memory payload = computeL1OwnershipClaimMessagePayload(l2TokenAddress, _msgSender());

        // consume ownership claim message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // transfer ownership
        Ownable(l1TokenAddress).transferOwnership(_msgSender());

        // emit event
        emit LogL1OwnershipClaimed(l2TokenAddress, l1TokenAddress, _msgSender());
    }

    // OWNERSHIP REQUEST

    function requestL2Ownership(address l1TokenAddress, uint256 l2Owner) public {
        // assert L1 token owner is sender
        address l1Owner = Ownable(l1TokenAddress).owner();
        require(l1Owner == _msgSender(), "Sender is not the owner");

        // compute L2 instance request payload and sent it
        (uint256[] memory payload, uint256 handlerSelector) = computeL2OwnershipClaimMessagePayload(
            l1TokenAddress,
            l2Owner
        );
        _state.starknetMessaging.sendMessageToL2(_state.l2KassAddress, handlerSelector, payload);

        // emit event
        emit LogL2OwnershipClaimed(l1TokenAddress, l2Owner);
    }

    // WITHDRAW

    function _withdraw(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        address l1Recipient,
        TokenStandard tokenStandard
    ) internal {
        require(amount > 0, "Cannot withdraw null amount");

        // compute L1 instance request payload
        uint256[] memory payload = tokenDepositOnL1MessagePayload(
            l2TokenAddress,
            tokenId,
            amount,
            l1Recipient,
            tokenStandard
        );

        // consume L1 withdraw request message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // mint tokens
        if (tokenStandard == TokenStandard.ERC721) {
            KassERC721(l1TokenAddress).mint(l1Recipient, tokenId);
        } else if (tokenStandard == TokenStandard.ERC1155) {
            KassERC1155(l1TokenAddress).mint(l1Recipient, tokenId, amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        // emit event
        emit LogWithdrawal(l2TokenAddress, l1TokenAddress, tokenId, amount, l1Recipient);
    }

    function withdraw721(uint256 l2TokenAddress, uint256 tokenId, address l1Recipient) public {
        _withdraw(l2TokenAddress, tokenId, 0x1, l1Recipient, TokenStandard.ERC721);
    }

    function withdraw1155(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) public {
        _withdraw(l2TokenAddress, tokenId, amount, l1Recipient, TokenStandard.ERC1155);
    }

    // DEPOSIT

    function _deposit(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        TokenStandard tokenStandard
    ) private {
        require(amount > 0, "Cannot deposit null amount");

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // burn tokens
        if (tokenStandard == TokenStandard.ERC721) {
            // check if sender is owner before burning
            require(KassERC721(l1TokenAddress).ownerOf(tokenId) == _msgSender(), "You do not own this token");

            KassERC721(l1TokenAddress).burn(tokenId);
        } else if (tokenStandard == TokenStandard.ERC1155) {
            KassERC1155(l1TokenAddress).burn(_msgSender(), tokenId, amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        // compute L2 deposit payload and sent it
        uint256[] memory payload = tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient);
        (, uint256 nonce) = _state.starknetMessaging.sendMessageToL2(
            _state.l2KassAddress,
            WITHDRAW_721_L2_HANDLER_SELECTOR,
            payload
        );

        // save depositor
        _state.depositors[nonce] = _msgSender();

        // emit event
        emit LogDeposit(_msgSender(), l2TokenAddress, l1TokenAddress, tokenId, amount, l2Recipient);
    }

    function deposit721(uint256 l2TokenAddress, uint256 tokenId, uint256 l2Recipient) public {
        _deposit(l2TokenAddress, tokenId, 0x1, l2Recipient, TokenStandard.ERC721);
    }

    function deposit1155(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, uint256 l2Recipient) public {
        _deposit(l2TokenAddress, tokenId, amount, l2Recipient, TokenStandard.ERC1155);
    }

    // REQUEST DEPOSIT CANCEL

    /**
     * If previous deposit on L2 fails to be handled by the L2 Kass bridge, tokens could be lost.
     * To mitigate this risk, L1 Kass bridge can cancel the deposit and after a security delay (5 days atm),
     * reclaim the tokens back on the L1.
     *
     * Such operation requires the depositor to provide deposit details & nonce.
     * The nonce should be extracted from the LogMessageToL2 event that was emitted by the
     * StarknetMessaging contract upon deposit.
     */
     function _requestDepositCancel(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) private {
        _state.starknetMessaging.startL1ToL2MessageCancellation(
            _state.l2KassAddress,
            WITHDRAW_721_L2_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        emit LogDepositCancelRequest(_msgSender(), l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    function requestDepositCancel721(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _requestDepositCancel(l2TokenAddress, tokenId, 0x1, l2Recipient, nonce);
    }

    function requestDepositCancel1155(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _requestDepositCancel(l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    // CANCEL DEPOSIT

    function _cancelDeposit(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce,
        TokenStandard tokenStandard
    ) private {
        _state.starknetMessaging.cancelL1ToL2Message(
            _state.l2KassAddress,
            WITHDRAW_721_L2_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // mint tokens
        if (tokenStandard == TokenStandard.ERC721) {
            KassERC721(l1TokenAddress).mint(_msgSender(), tokenId);
        } else if (tokenStandard == TokenStandard.ERC1155) {
            KassERC1155(l1TokenAddress).mint(_msgSender(), tokenId, amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        emit LogDepositCancel(_msgSender(), l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    function cancelDeposit721(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _cancelDeposit(l2TokenAddress, tokenId, 0x1, l2Recipient, nonce, TokenStandard.ERC721);
    }

    function cancelDeposit1155(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _cancelDeposit(l2TokenAddress, tokenId, amount, l2Recipient, nonce, TokenStandard.ERC1155);
    }

    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
