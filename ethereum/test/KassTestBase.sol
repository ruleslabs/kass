// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/Kass.sol";
import "../src/KassUtils.sol";
import "../src/mocks/StarknetMessagingMock.sol";
import "../src/KassMessagingPayloads.sol";
import "../src/StarknetConstants.sol";

abstract contract KassTestBase is Test, StarknetConstants, KassMessagingPayloads {
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
                abi.encodeWithSelector(Kass.initialize.selector, abi.encode(L2_KASS_ADDRESS, starknetMessaging))
            )
        );
        _kass = Kass(kassAddress);
    }

    // MESSAGES

    function requestL1WrapperCreation(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeL1WrapperCreationMessagePayload(l2TokenAddress, data, tokenStandard);

        // prepare L1 instance creation message from L2
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

    function claimOwnershipOnL1(uint256 l2TokenAddress, address l1Owner) internal {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                computeL1OwnershipClaimMessagePayload(l2TokenAddress, l1Owner)
            ),
            abi.encode(bytes32(0x0))
        );
    }

    function depositOnL1(
        uint256 l2TokenAddress,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeTokenDepositOnL1MessagePayload(
            l2TokenAddress,
            l1Recipient,
            tokenId,
            amount,
            tokenStandard
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

    // EXPECTS

    function expectL1WrapperCreation(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeL1WrapperCreationMessagePayload(l2TokenAddress, data, tokenStandard);

        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            messagePayload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL1WrapperCreated(bytes32(l2TokenAddress), l1TokenAddress);
    }

    function expectL2WrapperRequest(address l1TokenAddress) internal {
        // message
        (uint256[] memory payload, uint256 handlerSelector) = computeL2WrapperRequestMessagePayload(l1TokenAddress);
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // mock message sending return value
        vm.mockCall(
            _starknetMessagingAddress,
            messageCalldata,
            abi.encode(bytes32(0), 0)
        );

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL2WrapperRequested(l1TokenAddress);
    }

    function expectL1OwnershipClaim(uint256 l2TokenAddress, address l1Owner) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            computeL1OwnershipClaimMessagePayload(l2TokenAddress, l1Owner)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL1OwnershipClaimed(l2TokenAddress, l1TokenAddress, l1Owner);
    }

    function expectL2OwnershipRequest(address l1TokenAddress, uint256 l2Owner) internal {
        (uint256[] memory payload, uint256 handlerSelector) = computeL2OwnershipClaimMessagePayload(
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
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL2OwnershipClaimed(l1TokenAddress, l2Owner);
    }

    function expectDepositOnL2(
        uint256 l2TokenAddress,
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            bytes32(l2TokenAddress),
            l2Recipient,
            tokenId,
            amount
        );
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            handlerSelector,
            payload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // mock message sending return value
        vm.mockCall(
            _starknetMessagingAddress,
            messageCalldata,
            abi.encode(bytes32(0), uint256(nonce))
        );

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDeposit(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount);
    }

    function expectWithdrawOnL1(
        uint256 l2TokenAddress,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard
    ) internal returns (uint256[] memory messagePayload) {
        messagePayload = _computeTokenDepositOnL1MessagePayload(
            l2TokenAddress,
            l1Recipient,
            tokenId,
            amount,
            tokenStandard
        );

        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            messagePayload
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogWithdrawal(bytes32(l2TokenAddress), l1Recipient, tokenId, amount);
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancelRequest(
        uint256 l2TokenAddress,
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            bytes32(l2TokenAddress),
            l2Recipient,
            tokenId,
            amount
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
        emit LogDepositCancelRequest(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount, nonce);
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancel(
        uint256 l2TokenAddress,
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) internal {
        (uint256[] memory payload, uint256 handlerSelector) = computeTokenDepositMessagePayload(
            bytes32(l2TokenAddress),
            l2Recipient,
            tokenId,
            amount
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
        emit LogDepositCancel(bytes32(l2TokenAddress), sender, l2Recipient, tokenId, amount, nonce);
    }

    // INTERNALS

    function _computeL1WrapperCreationMessagePayload(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) private pure returns (uint256[] memory payload) {
        payload = new uint256[](data.length + 2);

        if (tokenStandard == TokenStandard.ERC721) {
            payload[0] = REQUEST_L1_721_INSTANCE;
        } else if (tokenStandard == TokenStandard.ERC1155) {
            payload[0] = REQUEST_L1_1155_INSTANCE;
        } else {
            revert("Kass: Unkown token standard");
        }

        // store L2 token address
        payload[1] = l2TokenAddress;

        // store token URI
        for (uint8 i = 0; i < data.length; ++i) {
            payload[i + 2] = KassUtils.strToFelt252(data[i]);
        }
    }

    function _computeTokenDepositOnL1MessagePayload(
        uint256 l2TokenAddress,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard
    ) internal pure returns (uint256[] memory payload) {
        if (tokenStandard == TokenStandard.ERC721) {
            payload = new uint256[](5);
            payload[0] = TRANSFER_721_FROM_STARKNET;
        } else if (tokenStandard == TokenStandard.ERC1155) {
            payload = new uint256[](7);
            payload[0] = TRANSFER_1155_FROM_STARKNET;

            payload[5] = uint128(amount & (UINT256_PART_SIZE - 1)); // low
            payload[6] = uint128(amount >> UINT256_PART_SIZE_BITS); // high
        } else {
            revert("Kass: Unkown token standard");
        }

        payload[1] = l2TokenAddress;

        payload[2] = uint256(uint160(l1Recipient));

        payload[3] = uint128(tokenId & (UINT256_PART_SIZE - 1)); // low
        payload[4] = uint128(tokenId >> UINT256_PART_SIZE_BITS); // high
    }
}
