// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
        bytes32 indexed tokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount
    );
    event LogWithdrawal(
        bytes32 indexed nativeTokenAddress,
        address indexed recipient,
        uint256 tokenId,
        uint256 amount
    );

    event LogDepositCancelRequest(
        bytes32 indexed l2TokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    );
    event LogDepositCancel(
        bytes32 indexed l2TokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount,
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
        (uint256[] memory payload, uint256 handlerSelector) = computeL2WrapperRequestMessagePayload(tokenAddress);
        _state.starknetMessaging.sendMessageToL2(_state.l2KassAddress, handlerSelector, payload);

        // emit event
        emit LogL2WrapperRequested(tokenAddress);
    }

    // OWNERSHIP CLAIM

    function claimL1Ownership(uint256 l2TokenAddress) public {
        // compute ownership claim payload and consume it
        uint256[] memory payload = computeL1OwnershipClaimMessagePayload(l2TokenAddress, _msgSender());
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

    // DEPOSIT

    function deposit(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount
    ) public {
        // get l1 token address (native or wrapper)
        address l1TokenAddress = getL1TokenAddres(tokenAddress);

        // TODO: token tranfer for L1 native tokens
        // burn or tranfer tokens
        if (_isERC721(l1TokenAddress)) {
            // check if sender is owner before burning
            require(KassERC721(l1TokenAddress).ownerOf(tokenId) == _msgSender(), "You do not own this token");

            KassERC721(l1TokenAddress).burn(tokenId);
        } else if (_isERC1155(l1TokenAddress)) {
            require(amount > 0, "Cannot deposit null amount");
            KassERC1155(l1TokenAddress).burn(_msgSender(), tokenId, amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        // compute l2 Wrapper Creation message payload and send it
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            tokenAddress,
            recipient,
            tokenId,
            amount
        );
        (, uint256 nonce) = _state.starknetMessaging.sendMessageToL2(_state.l2KassAddress, handlerSelector, payload);

        // save depositor
        _state.depositors[nonce] = _msgSender();

        // emit event
        emit LogDeposit(tokenAddress, _msgSender(), recipient, tokenId, amount);
    }

    function deposit(bytes32 tokenAddress, uint256 recipient, uint256 tokenId) public {
        deposit(tokenAddress, recipient, tokenId, 0x1);
    }

    // WITHDRAW

    function withdraw(uint256[] calldata messagePayload) public {
        // consume L1 withdraw request message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, messagePayload);

        // parse message payload
        DepositRequest memory depositRequest = parseDepositRequestMessagePayload(messagePayload);

        // get l1 token address (native or wrapper)
        address l1TokenAddress = getL1TokenAddres(depositRequest.tokenAddress);

        // TODO: token tranfer for L1 native tokens
        // mint or tranfer tokens
        if (depositRequest.tokenStandard == TokenStandard.ERC721) {
            KassERC721(l1TokenAddress).mint(depositRequest.recipient, depositRequest.tokenId);
        } else if (depositRequest.tokenStandard == TokenStandard.ERC1155) {
            require(depositRequest.amount > 0, "Cannot withdraw null amount");

            KassERC1155(l1TokenAddress).mint(depositRequest.recipient, depositRequest.tokenId, depositRequest.amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        // emit event
        emit LogWithdrawal(
            depositRequest.tokenAddress,
            depositRequest.recipient,
            depositRequest.tokenId,
            depositRequest.amount
        );
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
     function requestDepositCancel(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            tokenAddress,
            recipient,
            tokenId,
            amount
        );
        _state.starknetMessaging.startL1ToL2MessageCancellation(_state.l2KassAddress, handlerSelector, payload, nonce);

        emit LogDepositCancelRequest(tokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function requestDepositCancel(bytes32 tokenAddress, uint256 recipient, uint256 tokenId, uint256 nonce) public {
        requestDepositCancel(tokenAddress, recipient, tokenId, 0x1, nonce);
    }

    // CANCEL DEPOSIT

    function cancelDeposit(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            tokenAddress,
            recipient,
            tokenId,
            amount
        );
        _state.starknetMessaging.cancelL1ToL2Message(_state.l2KassAddress, handlerSelector, payload, nonce);

        address l1TokenAddress = getL1TokenAddres(tokenAddress);

        // TODO: token tranfer for L1 native tokens
        // mint or tranfer tokens
        if (_isERC721(l1TokenAddress)) {
            KassERC721(l1TokenAddress).mint(_msgSender(), tokenId);
        } else if (_isERC1155(l1TokenAddress)) {
            KassERC1155(l1TokenAddress).mint(_msgSender(), tokenId, amount);
        } else {
            revert("Kass: Unkown token standard");
        }

        emit LogDepositCancel(tokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function cancelDeposit(bytes32 tokenAddress, uint256 recipient, uint256 tokenId, uint256 nonce) public {
        cancelDeposit(tokenAddress, recipient, tokenId, 0x1, nonce);
    }

    // INTERNALS

    function _isERC721(address tokenAddress) private view returns (bool) {
        return ERC165(tokenAddress).supportsInterface(type(IERC721).interfaceId);
    }

    function _isERC1155(address tokenAddress) private view returns (bool) {
        return ERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId);
    }

    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
