// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/Kass.sol";
import "../src/KassUtils.sol";
import "../src/mocks/StarknetMessagingMock.sol";
import "../src/KassMessaging.sol";
import "../src/StarknetConstants.sol";

import "../src/factory/KassERC721.sol";
import "../src/factory/KassERC1155.sol";
import "../src/factory/KassERC1967Proxy.sol";

abstract contract KassTestBase is Test, StarknetConstants, KassMessaging {
    Kass internal _kass;
    address internal _starknetMessagingAddress;

    string internal constant L2_TOKEN_FLAT_URI = "https://api.rules.art/metadata/{id}.json";
    string internal constant L2_TOKEN_NAME = "L2 Kass Token";
    string internal constant L2_TOKEN_SYMBOL = "L2KT";

    // solhint-disable-next-line var-name-mixedcase
    string[] internal L2_TOKEN_URI;
    // solhint-disable-next-line var-name-mixedcase
    string[] internal L2_TOKEN_NAME_AND_SYMBOL;

    address internal constant STARKNET_MESSAGNING_ADDRESS = address(uint160(uint256(keccak256("starknet messaging"))));
    uint256 internal constant L2_KASS_ADDRESS = uint256(keccak256("L2 Kass"));
    uint256 internal constant L2_TOKEN_ADDRESS = uint256(keccak256("L2 token"));

    uint256 public constant CAIRO_FIELD_PRIME = 0x800000000000011000000000000000000000000000000000000000000000001;

    uint256 public constant L1_TO_L2_MESSAGE_FEE = 0x42;

    address public immutable proxyImplementationAddress = address(new KassERC1967Proxy());
    address public immutable erc721ImplementationAddress = address(new KassERC721());
    address public immutable erc1155ImplementationAddress = address(new KassERC1155());

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

    constructor () {
        // L2 token uri
        L2_TOKEN_URI = new string[](3);
        L2_TOKEN_URI[0] = "https://api.rule";
        L2_TOKEN_URI[1] = "s.art/metadata/{";
        L2_TOKEN_URI[2] = "id}.json";

        // L2 token name & symbol
        L2_TOKEN_NAME_AND_SYMBOL = new string[](2);
        L2_TOKEN_NAME_AND_SYMBOL[0] = L2_TOKEN_NAME;
        L2_TOKEN_NAME_AND_SYMBOL[1] = L2_TOKEN_SYMBOL;
    }

    // SETUP

    function setUp() public virtual {
        // setup starknet messaging mock
        IStarknetMessaging starknetMessaging = new StarknetMessagingMock();
        _starknetMessagingAddress = address(starknetMessaging);

        address implementationAddress = address(new Kass());

        // setup bridge
        address payable kassAddress = payable(
            new ERC1967Proxy(
                implementationAddress,
                abi.encodeWithSelector(
                    Kass.initialize.selector,
                    abi.encode(
                        address(this),
                        L2_KASS_ADDRESS,
                        starknetMessaging,
                        proxyImplementationAddress,
                        erc721ImplementationAddress,
                        erc1155ImplementationAddress
                    )
                )
            )
        );
        _kass = Kass(kassAddress);
    }

    // WRAPPER CREATION

    function _createL1Wrapper(uint256 tokenId, TokenStandard tokenStandard) internal returns (address l1TokenWrapper) {
        string[] memory data;

        if (tokenStandard == TokenStandard.ERC721) {
            data = L2_TOKEN_NAME_AND_SYMBOL;
        } else if (tokenStandard == TokenStandard.ERC1155) {
            data = L2_TOKEN_URI;
        } else {
            revert("Kass: Unknown token standard");
        }

        uint256 amount = 0x1;

        depositOnL1(bytes32(L2_TOKEN_ADDRESS), address(0x1), tokenId, amount, tokenStandard, data);
        uint256[] memory messagePayload = expectWithdrawOnL1(
            bytes32(L2_TOKEN_ADDRESS),
            address(0x1),
            tokenId,
            amount,
            tokenStandard,
            data
        );
        _kass.withdraw(messagePayload);

        l1TokenWrapper = _kass.computeL1TokenAddress(L2_TOKEN_ADDRESS);
    }

    function _createL1Wrapper(TokenStandard tokenStandard) internal returns (address) {
        return _createL1Wrapper(uint256(keccak256("wrapper request token")), tokenStandard);
    }

    // MESSAGES

    function claimOwnershipOnL1(uint256 l2TokenAddress, address l1Owner) internal {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner)
            ),
            abi.encode(bytes32(0x0))
        );
    }

    function depositOnL1(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        string[] memory data
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeTokenDepositOnL1Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            tokenStandard,
            data
        );

        // prepare L1 instance deposit message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                messagePayload
            ),
            abi.encode(bytes32(0x0))
        );
    }

    function depositOnL1(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        return depositOnL1(tokenAddress, recipient, tokenId, amount, tokenStandard, new string[](0));
    }

    // EXPECTS

    function expectL1OwnershipClaim(uint256 l2TokenAddress, address l1Owner) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL1OwnershipClaimed(l2TokenAddress, l1TokenAddress, l1Owner);
    }

    function expectL2OwnershipRequest(address l1TokenAddress, uint256 l2Owner) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeL2OwnershipClaimMessage(
            l1TokenAddress,
            l2Owner
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, L1_TO_L2_MESSAGE_FEE, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL2OwnershipClaimed(l1TokenAddress, l2Owner);
    }

    function expectDepositOnL2(
        bytes32 tokenAddress,
        address sender,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, L1_TO_L2_MESSAGE_FEE, messageCalldata);

        // mock message sending return value
        vm.mockCall(
            _starknetMessagingAddress,
            messageCalldata,
            abi.encode(bytes32(0), uint256(nonce))
        );

        // expect events
        if (requestWrapper) {
            vm.expectEmit(true, true, true, true, address(_kass));
            emit LogL2WrapperRequested(address(uint160(uint256(tokenAddress))));
        }

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDeposit(tokenAddress, sender, recipient, tokenId, amount);
    }

    function expectWithdrawOnL1(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        string[] memory data
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeTokenDepositOnL1Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            tokenStandard,
            data
        );

        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            messagePayload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect events
        if (data.length > 0) {
            address computedWrapperAddress = _kass.computeL1TokenAddress(uint256(tokenAddress));

            if (!Address.isContract(computedWrapperAddress)) {
                vm.expectEmit(true, true, true, true, address(_kass));
                emit LogL1WrapperCreated(tokenAddress, computedWrapperAddress);
            }
        }

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogWithdrawal(tokenAddress, recipient, tokenId, amount);
    }

    function expectWithdrawOnL1(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        return expectWithdrawOnL1(tokenAddress, recipient, tokenId, amount, tokenStandard, new string[](0));
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancelRequest(
        bytes32 tokenAddress,
        address sender,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.startL1ToL2MessageCancellation.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload,
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDepositCancelRequest(tokenAddress, sender, recipient, tokenId, amount, nonce);
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancel(
        bytes32 tokenAddress,
        address sender,
        uint256 recipient,
        uint256 tokenId,
        uint256 amount,
        bool requestWrapper,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.cancelL1ToL2Message.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload,
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDepositCancel(tokenAddress, sender, recipient, tokenId, amount, nonce);
    }

    // INTERNALS

    function _computeTokenDepositOnL1Message(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        string[] memory data
    ) internal pure returns (uint256[] memory payload) {
        if (data.length > 0) {
            payload = new uint256[](data.length + 7);

            if (tokenStandard == TokenStandard.ERC721) {
                payload[0] = DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1;
            } else if (tokenStandard == TokenStandard.ERC1155) {
                payload[0] = DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1;
            } else {
                revert("Kass: Unknown token standard");
            }

            // store token URI
            for (uint8 i = 0; i < data.length; ++i) {
                payload[i + 7] = KassUtils.strToFelt252(data[i]);
            }
        } else {
            payload = new uint256[](7);

            payload[0] = DEPOSIT_TO_L1;
        }

        payload[1] = uint256(tokenAddress);

        payload[2] = uint256(uint160(recipient));

        payload[3] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // low
        payload[4] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // high

        payload[5] = uint128(amount & (UINT256_PART_SIZE - 1)); // low
        payload[6] = uint128(amount >> UINT256_PART_SIZE_BITS); // high
    }
}
