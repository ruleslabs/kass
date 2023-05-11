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
import "./KassMessaging.sol";
import "./KassStorage.sol";

contract Kass is Ownable, KassStorage, TokenDeployer, KassMessaging, UUPSUpgradeable {

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
        (
            uint256 l2KassAddress_,
            IStarknetMessaging starknetMessaging_,
            address proxyImplementationAddress_,
            address erc721ImplementationAddress_,
            address erc1155ImplementationAddress_
        ) = abi.decode(
            data,
            (uint256, IStarknetMessaging, address, address, address)
        );
        _state.l2KassAddress = l2KassAddress_;
        _state.starknetMessaging = starknetMessaging_;

        _setDeployerImplementations(
            proxyImplementationAddress_,
            erc721ImplementationAddress_,
            erc1155ImplementationAddress_
        );

        _transferOwnership(_msgSender());
    }

    // UPGRADE

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    // GETTERS

    function l2KassAddress() public view returns (uint256) {
        return _state.l2KassAddress;
    }

    function proxyImplementationAddress() public view returns (address) {
        return _state.proxyImplementationAddress;
    }

    function erc721ImplementationAddress() public view returns (address) {
        return _state.erc721ImplementationAddress;
    }

    function erc1155ImplementationAddress() public view returns (address) {
        return _state.erc1155ImplementationAddress;
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

    // OWNERSHIP CLAIM

    function claimL1Ownership(uint256 l2TokenAddress) public {
        // consume ownership claim message
        _consumeL1OwnershipClaimMessage(l2TokenAddress, _msgSender());

        // get l1 token wrapper
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // transfer ownership
        Ownable(l1TokenAddress).transferOwnership(_msgSender());

        // emit event
        emit LogL1OwnershipClaimed(l2TokenAddress, l1TokenAddress, _msgSender());
    }

    // OWNERSHIP REQUEST

    function requestL2Ownership(address l1TokenAddress, uint256 l2Owner) public payable {
        // assert L1 token owner is sender
        address l1Owner = Ownable(l1TokenAddress).owner();
        require(l1Owner == _msgSender(), "Sender is not the owner");

        // send L2 wrapper request message
        _sendL2OwnershipClaimMessage(l1TokenAddress, l2Owner, msg.value);

        // emit event
        emit LogL2OwnershipClaimed(l1TokenAddress, l2Owner);
    }

    // DEPOSIT

    function deposit(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper
    ) public payable {
        // get l1 token address (native or wrapper)
        (address l1TokenAddress, bool isNative) = getL1TokenAddres(tokenAddress);

        // avoid double wrap
        require(isNative || !requestWrapper, "Kass: Double wrap not allowed");

        // burn or tranfer tokens
        _lockTokens(l1TokenAddress, tokenId, amount, isNative);

        // send l2 Wrapper Creation message
        uint256 nonce = _sendTokenDepositMessage(
            tokenAddress,
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
            emit LogL2WrapperRequested(l1TokenAddress);
        }
        emit LogDeposit(tokenAddress, _msgSender(), recipient, tokenId, amount);
    }

    function deposit(bytes32 tokenAddress, uint256 recipient, uint256 tokenId, bool requestWrapper) public payable {
        deposit(tokenAddress, recipient, tokenId, 0x1, requestWrapper);
    }

    // WITHDRAW

    function withdraw(uint256[] calldata messagePayload) public {
        // consume L1 wrapper request message
        _consumeL1WrapperRequestMessage(messagePayload);

        // parse message payload
        DepositRequest memory depositRequest = _parseDepositRequestMessagePayload(messagePayload);

        // get l1 token address (native or wrapper)
        (address l1TokenAddress, bool isNative) = getL1TokenAddres(depositRequest.tokenAddress);

        if (!Address.isContract(l1TokenAddress)) {
            require(depositRequest.tokenStandard != TokenStandard.UNKNOWN, "Kass: wrapper not deployed");

            // deploy Kass ERC-721/1155
            if (depositRequest.tokenStandard == TokenStandard.ERC721) {
                cloneKassERC721(depositRequest.tokenAddress, depositRequest._calldata);
            } else if (depositRequest.tokenStandard == TokenStandard.ERC1155) {
                cloneKassERC1155(depositRequest.tokenAddress, depositRequest._calldata);
            } else {
                revert("Kass: Unknown token standard");
            }

            // emit event
            emit LogL1WrapperCreated(depositRequest.tokenAddress, l1TokenAddress);
        }

        // mint or tranfer tokens
        _unlockTokens(
            l1TokenAddress,
            depositRequest.recipient,
            depositRequest.tokenId,
            depositRequest.amount,
            isNative
        );

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
        bool requestWrapper,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        // start token deposit message cancellation
        _startL1ToL2TokenDepositMessageCancellation(tokenAddress, recipient, tokenId, amount, requestWrapper, nonce);

        emit LogDepositCancelRequest(tokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function requestDepositCancel(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) public {
        requestDepositCancel(tokenAddress, recipient, tokenId, 0x1, requestWrapper, nonce);
    }

    // CANCEL DEPOSIT

    function cancelDeposit(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        // cancel token deposit message
        _cancelL1ToL2TokenDepositMessage(tokenAddress, recipient, tokenId, amount, requestWrapper, nonce);

        (address l1TokenAddress, bool isNative) = getL1TokenAddres(tokenAddress);

        // mint or tranfer tokens
        _unlockTokens(l1TokenAddress, _msgSender(), tokenId, amount, isNative);

        emit LogDepositCancel(tokenAddress, _msgSender(), recipient, tokenId, amount, nonce);
    }

    function cancelDeposit(
        bytes32 tokenAddress,
        uint256 recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) public {
        cancelDeposit(tokenAddress, recipient, tokenId, 0x1, requestWrapper, nonce);
    }

    // SAFE TRANSFERS CHECK

    function onERC1155Received(address operator, address, uint256, uint256, bytes memory) public view returns (bytes4) {
        return operator == address(this) ? this.onERC1155Received.selector : bytes4(0);
    }

    // INTERNALS

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

    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
