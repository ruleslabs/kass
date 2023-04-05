// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

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
    event LogL1InstanceCreated(uint256 indexed l2TokenAddress, address l1TokenAddress);
    event LogOwnershipClaimed(
        uint256 indexed l2TokenAddress,
        address l1TokenAddress,
        address l1Owner
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

    // BUSINESS LOGIC

    function createL1Instance(uint256 l2TokenAddress, string[] calldata uri) public returns (address l1TokenAddress) {
        // compute L1 instance request payload
        uint256[] memory payload = instanceCreationMessagePayload(l2TokenAddress, uri);

        // consume L1 instance request message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);

        // deploy Kass ERC1155 with URI
        l1TokenAddress = cloneKassERC1155(bytes32(l2TokenAddress), KassUtils.concat(uri));

        // emit event
        emit LogL1InstanceCreated(l2TokenAddress, l1TokenAddress);
    }

    function claimOwnership(uint256 l2TokenAddress) public {
        // compute ownership claim payload
        uint256[] memory payload = ownershipClaimMessagePayload(l2TokenAddress, _msgSender());

        // consume ownership claim message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // transfer ownership
        KassERC1155(l1TokenAddress).transferOwnership(_msgSender());

        // emit event
        emit LogOwnershipClaimed(l2TokenAddress, l1TokenAddress, _msgSender());
    }

    function withdraw(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) public {
        require(amount > 0, "Cannot withdraw null amount");

        // compute L1 instance request payload
        uint256[] memory payload = tokenDepositOnL1MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient);

        // consume L1 withdraw request message
        _state.starknetMessaging.consumeMessageFromL2(_state.l2KassAddress, payload);

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // mint tokens
        KassERC1155(l1TokenAddress).mint(l1Recipient, tokenId, amount);

        // emit event
        emit LogWithdrawal(l2TokenAddress, l1TokenAddress, tokenId, amount, l1Recipient);
    }

    function deposit(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, uint256 l2Recipient) public {
        require(amount > 0, "Cannot deposit null amount");

        // get l1 token instance
        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // burn tokens
        KassERC1155(l1TokenAddress).burn(_msgSender(), tokenId, amount);

        // compute L2 deposit payload and sent it
        uint256[] memory payload = tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient);
        (, uint256 nonce) = _state.starknetMessaging.sendMessageToL2(
            _state.l2KassAddress,
            DEPOSIT_HANDLER_SELECTOR,
            payload
        );

        // save depositor
        _state.depositors[nonce] = _msgSender();

        // emit event
        emit LogDeposit(_msgSender(), l2TokenAddress, l1TokenAddress, tokenId, amount, l2Recipient);
    }

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
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _state.starknetMessaging.startL1ToL2MessageCancellation(
            _state.l2KassAddress,
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        emit LogDepositCancelRequest(_msgSender(), l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    function cancelDeposit(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _state.starknetMessaging.cancelL1ToL2Message(
            _state.l2KassAddress,
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // mint tokens
        KassERC1155(l1TokenAddress).mint(_msgSender(), tokenId, amount);

        emit LogDepositCancel(_msgSender(), l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
