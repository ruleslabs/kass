// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import "./ERC1155/KassERC1155.sol";
import "./interfaces/IStarknetMessaging.sol";
import "./KassUtils.sol";
import "./TokenDeployer.sol";
import "./StarknetConstants.sol";
import "./KassMessagingPayloads.sol";
import "./KassStorage.sol";

contract Kass is Ownable, KassStorage, TokenDeployer, KassMessagingPayloads, ERC1967Upgrade {

    // EVENTS

    // L1 token address can be computed offchain from L2 token address
    // it does not need to be indexed
    event LogL1InstanceCreated(uint256 indexed l2TokenAddress, address l1TokenAddress);
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

        require(!isInitialized(implementation), "already initialized");

        setInitialized(implementation);

        _;
    }

    modifier onlyDepositor(uint256 nonce) {
        address depositor_ = _depositors()[nonce];

        require(depositor_ != address(0x0), "Deposit not found");
        require(depositor_ == msg.sender, "Caller is not the depositor");

        _;
    }

    // INIT

    function initialize(bytes calldata data) public virtual initializer {
        (uint256 l2KassAddress_, IStarknetMessaging starknetMessaging_) = abi.decode(
            data,
            (uint256, IStarknetMessaging)
        );
        _l2KassAddress(l2KassAddress_);
        _starknetMessaging(starknetMessaging_);

        setDeployerBaseToken();

        _transferOwnership(msg.sender);
    }

    // GETTERS

    function l2KassAddress() public view returns (uint256) {
        return _l2KassAddress();
    }

    function isInitialized(address implementation) public view returns (bool) {
        return _initializedImplementations()[implementation];
    }

    // SETTERS

    function setL2KassAddress(uint256 l2KassAddress_) public onlyOwner {
        _l2KassAddress(l2KassAddress_);
    }

    function setInitialized(address implementation) private {
        _initializedImplementations(implementation, true);
    }

    // BUSINESS LOGIC

    function createL1Instance(uint256 l2TokenAddress, string[] calldata uri) public returns (address l1TokenAddress) {
        // compute L1 instance request payload
        uint256[] memory payload = instanceCreationMessagePayload(l2TokenAddress, uri);

        // consume L1 instance request message
        _starknetMessaging().consumeMessageFromL2(l2KassAddress(), payload);

        // deploy Kass ERC1155 and set URI
        l1TokenAddress = cloneKassERC1155(bytes32(l2TokenAddress));
        KassERC1155(l1TokenAddress).init(KassUtils.concat(uri));

        // emit event
        emit LogL1InstanceCreated(l2TokenAddress, l1TokenAddress);
    }

    function withdraw(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) public {
        require(amount > 0, "Cannot withdraw null amount");

        // compute L1 instance request payload
        uint256[] memory payload = tokenDepositOnL1MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient);

        // consume L1 withdraw request message
        _starknetMessaging().consumeMessageFromL2(_l2KassAddress(), payload);

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
        KassERC1155(l1TokenAddress).burn(msg.sender, tokenId, amount);

        // compute L2 deposit payload and sent it
        uint256[] memory payload = tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient);
        (, uint256 nonce) = _starknetMessaging().sendMessageToL2(_l2KassAddress(), DEPOSIT_HANDLER_SELECTOR, payload);

        // save depositor
        _depositors(nonce, msg.sender);

        // emit event
        emit LogDeposit(msg.sender, l2TokenAddress, l1TokenAddress, tokenId, amount, l2Recipient);
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
        _starknetMessaging().startL1ToL2MessageCancellation(
            _l2KassAddress(),
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        emit LogDepositCancelRequest(msg.sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    function cancelDeposit(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) public onlyDepositor(nonce) {
        _starknetMessaging().cancelL1ToL2Message(
            _l2KassAddress(),
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        address l1TokenAddress = computeL1TokenAddress(l2TokenAddress);

        // mint tokens
        KassERC1155(l1TokenAddress).mint(msg.sender, tokenId, amount);

        emit LogDepositCancel(msg.sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    fallback() external payable { revert("unsupported"); }
    receive() external payable { revert("Kass does not accept assets"); }
}
