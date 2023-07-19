// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./factory/ERC721.sol";
import "./factory/ERC1155.sol";
import "./interfaces/IStarknetMessaging.sol";
import "./Utils.sol";
import "./TokenDeployer.sol";
import "./StarknetConstants.sol";
import "./Messaging.sol";
import "./Storage.sol";
import "./Events.sol";

contract KassBridge is Ownable, KassStorage, KassTokenDeployer, KassMessaging, KassEvents, UUPSUpgradeable {

    //
    // Modifiers
    //

    modifier initializer() {
        address implementation = _getImplementation();

        require(!_isInitialized(implementation), "Already initialized");

        _setInitialized(implementation);

        _;
    }

    modifier onlyDepositor(uint256 nonce) {
        address depositor_ = _state.depositors[nonce];

        require(depositor_ != address(0x0), "Deposit not found");
        require(depositor_ == _msgSender(), "Caller is not the depositor");

        _;
    }

    //
    // Initialize
    //

    function initialize(bytes calldata data) public initializer {
        (
            address owner,
            uint256 l2KassAddress_,
            IStarknetMessaging starknetMessaging_,
            address proxyImplementationAddress_,
            address erc721ImplementationAddress_,
            address erc1155ImplementationAddress_
        ) = abi.decode(
            data,
            (address, uint256, IStarknetMessaging, address, address, address)
        );
        _state.l2KassAddress = l2KassAddress_;
        _state.starknetMessaging = starknetMessaging_;

        super.setDeployerImplementations(
            proxyImplementationAddress_,
            erc721ImplementationAddress_,
            erc1155ImplementationAddress_
        );

        _transferOwnership(owner);
    }

    //
    // Upgrade
    //

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    //
    // Kass Messaging
    //

    function setL2KassAddress(uint256 l2KassAddress_) public override onlyOwner() {
        super.setL2KassAddress(l2KassAddress_);
    }

    //
    // Kass Token Deployer
    //

    function setDeployerImplementations(
        address proxyImplementationAddress_,
        address erc721ImplementationAddress_,
        address erc1155ImplementationAddress_
    ) public override onlyOwner() {
        super.setDeployerImplementations(
            proxyImplementationAddress_,
            erc721ImplementationAddress_,
            erc1155ImplementationAddress_
        );
    }

    //
    // Kass Bridge
    //

    // Ownership

    function claimOwnership(uint256 l2TokenAddress, address owner) public {
        // consume ownership claim message
        _consumeL1OwnershipClaimMessage(l2TokenAddress, owner);

        // get l1 token wrapper
        address l1TokenAddress = getL1TokenAddress(l2TokenAddress);

        // transfer ownership
        Ownable(l1TokenAddress).transferOwnership(owner);

        // emit event
        emit LogOwnershipClaim(l2TokenAddress, l1TokenAddress, owner);
    }

    function requestOwnership(address l1TokenAddress, uint256 l2Owner) public payable {
        // assert L1 token owner is sender
        address l1Owner = Ownable(l1TokenAddress).owner();
        require(l1Owner == _msgSender(), "Sender is not the owner");

        // send L2 wrapper request message
        _sendL2OwnershipClaimMessage(l1TokenAddress, l2Owner, msg.value);

        // emit event
        emit LogOwnershipRequest(l1TokenAddress, l2Owner);
    }

    // Deposit

    function deposit(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper
    ) public payable {
        _deposit(nativeTokenAddress, recipient, tokenId, amount, requestWrapper);
    }

    function deposit(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        bool requestWrapper
    ) public payable {
        _deposit(nativeTokenAddress, recipient, tokenId, 0x1, requestWrapper);
    }

    // Withdraw

    function withdraw(uint256[] calldata messagePayload) public {
        // consume L1 wrapper request message
        _consumeL1WrapperRequestMessage(messagePayload);

        // parse message payload
        DepositRequest memory depositRequest = _parseDepositRequestMessagePayload(messagePayload);

        // get l1 token address (native or wrapper)
        (address l1TokenAddress, bool isL1Native) = _parseNativeTokenAddress(depositRequest.nativeTokenAddress);

        if (!Address.isContract(l1TokenAddress)) {
            require(depositRequest.tokenStandard != TokenStandard.UNKNOWN, "Kass: Wrapper not deployed");

            // deploy Kass ERC-721/1155
            uint256 l2TokenAddress = uint256(depositRequest.nativeTokenAddress);

            if (depositRequest.tokenStandard == TokenStandard.ERC721) {
                l1TokenAddress = _cloneKassERC721(l2TokenAddress, depositRequest._calldata);
            } else if (depositRequest.tokenStandard == TokenStandard.ERC1155) {
                l1TokenAddress = _cloneKassERC1155(l2TokenAddress, depositRequest._calldata);
            } else {
                revert("Kass: Unknown token standard");
            }

            // emit event
            emit LogWrapperCreation(l2TokenAddress, l1TokenAddress);
        }

        // mint or tranfer tokens
        _unlockTokens(
            l1TokenAddress,
            depositRequest.recipient,
            depositRequest.tokenId,
            depositRequest.amount,
            isL1Native
        );

        // emit event
        emit LogWithdraw(
            depositRequest.nativeTokenAddress,
            depositRequest.recipient,
            depositRequest.tokenId,
            depositRequest.amount
        );
    }

    // Deposit cancel

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
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        // start token deposit message cancellation
        _startL1ToL2TokenDepositMessageCancellation(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper,
            nonce
        );

        emit LogDepositCancelRequest(nativeTokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function requestDepositCancel(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) public {
        requestDepositCancel(nativeTokenAddress, recipient, tokenId, 0x1, requestWrapper, nonce);
    }

    function cancelDeposit(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        // cancel token deposit message
        _cancelL1ToL2TokenDepositMessage(nativeTokenAddress, recipient, tokenId, amount, requestWrapper, nonce);

        // get l1 token address (native or wrapper)
        (address l1TokenAddress, bool isL1Native) = _parseNativeTokenAddress(nativeTokenAddress);

        // mint or tranfer tokens
        _unlockTokens(l1TokenAddress, _msgSender(), tokenId, amount, isL1Native);

        emit LogDepositCancel(nativeTokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function cancelDeposit(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) public {
        cancelDeposit(nativeTokenAddress, recipient, tokenId, 0x1, requestWrapper, nonce);
    }

    //
    // ERC1155 receiver
    //

    function onERC1155Received(address operator, address, uint256, uint256, bytes memory) public view returns (bytes4) {
        return operator == address(this) ? this.onERC1155Received.selector : bytes4(0);
    }

    //
    // Internals
    //

    // Init
    function _isInitialized(address implementation) private view returns (bool) {
        return _state.initializedImplementations[implementation];
    }

    function _setInitialized(address implementation) private {
        _state.initializedImplementations[implementation] = true;
    }

    // Native/wrapper mgmt
    function _parseNativeTokenAddress(
        bytes32 nativeTokenAddress
    ) private view returns (address l1TokenAddress, bool isL1Native) {
        address castedNativeTokenAddress = address(uint160(uint256(nativeTokenAddress)));

        if (Address.isContract(castedNativeTokenAddress)) {
            l1TokenAddress = castedNativeTokenAddress;
            isL1Native = true;
        } else {
            l1TokenAddress = getL1TokenAddress(uint256(nativeTokenAddress));
            isL1Native = false;
        }
    }

    // Deposit
    function _deposit(
        bytes32 nativeTokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper
    ) private {
        // get l1 token address (native or wrapper)
        (address l1TokenAddress, bool isL1Native) = _parseNativeTokenAddress(nativeTokenAddress);

        // avoid double wrap
        require(isL1Native || !requestWrapper, "Kass: Double wrap not allowed");

        // burn or tranfer tokens
        _lockTokens(l1TokenAddress, tokenId, amount, isL1Native);

        // send l2 deposit message
        uint256 nonce = _sendTokenDepositMessage(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper,
            msg.value
        );

        // save depositor
        _state.depositors[nonce] = _msgSender();

        // emit events
        if (requestWrapper) {
            emit LogWrapperRequest(l1TokenAddress);
        }
        emit LogDeposit(nativeTokenAddress, _msgSender(), recipient, tokenId, amount);
    }

    // Tokens lock
    function _lockTokens(address tokenAddress, uint256 tokenId, uint256 amount, bool isNative) private {
        // burn or tranfer tokens
        if (KassUtils.isERC721(tokenAddress)) {
            if (isNative) {
                KassERC721(tokenAddress).transferFrom(_msgSender(), address(this), tokenId);
            } else {
                // check if sender is owner before burning
                require(KassERC721(tokenAddress).ownerOf(tokenId) == _msgSender(), "You do not own this token");

                KassERC721(tokenAddress).permissionedBurn(tokenId);
            }
        } else if (KassUtils.isERC1155(tokenAddress)) {
            require(amount > 0, "Cannot deposit null amount");

            if (isNative) {
                KassERC1155(tokenAddress).safeTransferFrom(_msgSender(), address(this), tokenId, amount, "");
            } else {
                KassERC1155(tokenAddress).permissionedBurn(_msgSender(), tokenId, amount);
            }
        } else {
            revert("Kass: Unknown token standard");
        }
    }

    function _unlockTokens(
        address tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        bool isNative
    ) private {
        // burn or tranfer tokens
        if (KassUtils.isERC721(tokenAddress)) {
            if (isNative) {
                KassERC721(tokenAddress).transferFrom(address(this), recipient, tokenId);
            } else {
                KassERC721(tokenAddress).permissionedMint(recipient, tokenId);
            }
        } else if (KassUtils.isERC1155(tokenAddress)) {
            require(amount > 0, "Cannot withdraw null amount");

            if (isNative) {
                KassERC1155(tokenAddress).safeTransferFrom(address(this), recipient, tokenId, amount, "");
            } else {
                KassERC1155(tokenAddress).permissionedMint(recipient, tokenId, amount);
            }
        } else {
            revert("Kass: Unknown token standard");
        }
    }

    // Misc
    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
