// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../../src/Bridge.sol";
import "../../src/Events.sol";
import "../../src/TokenDeployer.sol";
import "../../src/Utils.sol";
import "../../src/Messaging.sol";

import "../../src/factory/ERC721.sol";
import "../../src/factory/ERC1155.sol";
import "../../src/factory/ERC1967Proxy.sol";

import "../mocks/StarknetMessagingMock.sol";
import "../mocks/ERC721.sol";
import "../mocks/ERC1155.sol";
import "./Constants.sol";
import "./Starknet.sol";

abstract contract KassTestBase is Test, KassEvents, KassMessaging, ERC721Holder, ERC1155Holder {

    //
    // Storage
    //

    MockERC721 internal _erc721;
    MockERC1155 internal _erc1155;

    address internal _proxyImplementationAddress;
    address internal _erc721ImplementationAddress;
    address internal _erc1155ImplementationAddress;

    Starknet internal _starknet;
    KassBridge internal _kassBridge;

    address internal _starknetMessagingAddress;

    //
    // Setup
    //

    function setUp() public {
        // setup starknet messaging mock
        IStarknetMessaging starknetMessaging = new StarknetMessagingMock();
        _starknetMessagingAddress = address(starknetMessaging);

        address implementationAddress = address(new KassBridge());

        // setup implementations
        _proxyImplementationAddress = address(new KassERC1967Proxy());
        _erc721ImplementationAddress = address(new KassERC721());
        _erc1155ImplementationAddress = address(new KassERC1155());

        // setup bridge
        address payable kassAddress = payable(
            new ERC1967Proxy(
                implementationAddress,
                abi.encodeWithSelector(
                    KassBridge.initialize.selector,
                    abi.encode(
                        address(this),
                        Constants.L2_KASS_ADDRESS(),
                        starknetMessaging,
                        _proxyImplementationAddress,
                        _erc721ImplementationAddress,
                        _erc1155ImplementationAddress
                    )
                )
            )
        );
        _kassBridge = KassBridge(kassAddress);

        // setup starknet
        _starknet = new Starknet(_starknetMessagingAddress);

        // setup native tokens
        _erc721 = new MockERC721(Constants.L2_TOKEN_NAME(), Constants.L2_TOKEN_SYMBOL());
        _erc721.mint(address(this), Constants.TOKEN_ID());
        _erc721.mint(address(this), Constants.HUGE_TOKEN_ID());

        _erc1155 = new MockERC1155(Constants.L2_TOKEN_FLAT_URI());
        _erc1155.mint(address(this), Constants.TOKEN_ID(), Constants.TOKEN_AMOUNT());
        _erc1155.mint(address(this), Constants.HUGE_TOKEN_ID(), Constants.HUGE_TOKEN_AMOUNT());
    }

    // Wrapper creation

    function setupWrapper(TokenStandard tokenStandard, uint256 tokenId, uint256 amount) public returns (address) {
        address l1Recipient = address(this);
        bytes32 nativeTokenAddress = bytes32(Constants.L2_TOKEN_ADDRESS());

        uint256[] memory messagePayload = _starknet.deposit(
            nativeTokenAddress,
            l1Recipient,
            tokenId,
            amount,
            tokenStandard,
            true
        );

        _kassBridge.withdraw(messagePayload);

        return _kassBridge.computeL1TokenAddress(Constants.L2_TOKEN_ADDRESS());
    }

    function setupWrapper(TokenStandard tokenStandard, uint256 tokenId) public returns (address) {
        return setupWrapper(tokenStandard, tokenId, 0x1);
    }

    function setupWrapper(TokenStandard tokenStandard) public returns (address) {
        return setupWrapper(tokenStandard, uint256(keccak256("wrapper request tokenId")));
    }

    // Ownership

    function _expectOwnershipClaim(uint256 l2TokenAddress, address l1Owner) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            Constants.L2_KASS_ADDRESS(),
            _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kassBridge.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogOwnershipClaim(l2TokenAddress, l1TokenAddress, l1Owner);
    }

    function _expectOwnershipRequest(address l1TokenAddress, uint256 l2Owner) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeL2OwnershipClaimMessage(
            l1TokenAddress,
            l2Owner
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            Constants.L2_KASS_ADDRESS(),
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, Constants.L1_TO_L2_MESSAGE_FEE(), messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogOwnershipRequest(l1TokenAddress, l2Owner);
    }

    // Deposit

    function _expectDeposit(
        bytes32 nativeTokenAddress,
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            Constants.L2_KASS_ADDRESS(),
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, Constants.L1_TO_L2_MESSAGE_FEE(), messageCalldata);

        // mock message sending return value
        vm.mockCall(
            _starknetMessagingAddress,
            messageCalldata,
            abi.encode(bytes32(0), uint256(nonce))
        );

        // expect events
        if (requestWrapper) {
            vm.expectEmit(true, true, true, true, address(_kassBridge));
            emit LogWrapperRequest(address(uint160(uint256(nativeTokenAddress))));
        }

        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount);
    }

    // Withdraw

    function _expectWithdraw(
        bytes32 nativeTokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        bool requestWrapper
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _starknet.deposit(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            tokenStandard,
            requestWrapper
        );

        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            Constants.L2_KASS_ADDRESS(),
            messagePayload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect events
        if (requestWrapper && !KassUtils.isEthereumAddress(nativeTokenAddress)) {
            address computedWrapperAddress = _kassBridge.computeL1TokenAddress(uint256(nativeTokenAddress));

            if (!Address.isContract(computedWrapperAddress)) {
                vm.expectEmit(true, true, true, true, address(_kassBridge));
                emit LogWrapperCreation(uint256(nativeTokenAddress), computedWrapperAddress);
            }
        }

        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogWithdraw(nativeTokenAddress, recipient, tokenId, amount);
    }

    function _expectWithdraw(
        bytes32 nativeTokenAddress,
        address recipient,
        uint256 tokenId,
        TokenStandard tokenStandard,
        bool requestWrapper
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _expectWithdraw(nativeTokenAddress, recipient, tokenId, 0x1, tokenStandard, requestWrapper);
    }

    // Deposit cancel

    /**
     * cannot test nonce logic since it's handled by the starknet messaging contract.
     */
    function _expectDepositCancelRequest(
        bytes32 nativeTokenAddress,
        address sender,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.startL1ToL2MessageCancellation.selector,
            Constants.L2_KASS_ADDRESS(),
            handlerSelector,
            payload,
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogDepositCancelRequest(nativeTokenAddress, sender, recipient, tokenId, amount, nonce);
    }

    /**
     * cannot test nonce logic since it's handled by the starknet messaging contract.
     */
    function _expectDepositCancel(
        bytes32 nativeTokenAddress,
        address sender,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.cancelL1ToL2Message.selector,
            Constants.L2_KASS_ADDRESS(),
            handlerSelector,
            payload,
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kassBridge));
        emit LogDepositCancel(nativeTokenAddress, sender, recipient, tokenId, amount, nonce);
    }

    //
    // Helpers
    //

    function _bytes32(address address_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address_)));
    }

    function _bytes32(uint256 address_) internal pure returns (bytes32) {
        return bytes32(address_);
    }
}
