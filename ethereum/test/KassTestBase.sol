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

    event LogL1InstanceCreated(uint256 indexed l2TokenAddress, address l1TokenAddress);
    event LogL2InstanceRequested(address indexed l1TokenAddress);

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

    function requestL1InstanceCreation(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) internal {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                l1InstanceCreationMessagePayload(l2TokenAddress, data, tokenStandard)
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
                l1OwnershipClaimMessagePayload(l2TokenAddress, l1Owner)
            ),
            abi.encode(bytes32(0x0))
        );
    }

    function depositOnL1(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) internal {
        // prepare L1 instance deposit message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                tokenDepositOnL1MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient)
            ),
            abi.encode(bytes32(0x0))
        );
    }

    // EXPECTS

    function expectL1InstanceCreation(
        uint256 l2TokenAddress,
        string[] memory data,
        TokenStandard tokenStandard
    ) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            l1InstanceCreationMessagePayload(l2TokenAddress, data, tokenStandard)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL1InstanceCreated(l2TokenAddress, l1TokenAddress);
    }

    function expectL2InstanceRequest(
        address l1TokenAddress,
        uint256[] memory data,
        TokenStandard tokenStandard
    ) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            INSTANCE_CREATION_HANDLER_SELECTOR,
            l2InstanceCreationMessagePayload(l1TokenAddress, data, tokenStandard)
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
        emit LogL2InstanceRequested(l1TokenAddress);
    }

    function expectL1OwnershipClaim(uint256 l2TokenAddress, address l1Owner) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            l1OwnershipClaimMessagePayload(l2TokenAddress, l1Owner)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL1OwnershipClaimed(l2TokenAddress, l1TokenAddress, l1Owner);
    }

    function expectL2OwnershipRequest(address l1TokenAddress, uint256 l2Owner) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            OWNERSHIP_CLAIM_HANDLER_SELECTOR,
            l2OwnershipClaimMessagePayload(l1TokenAddress, l2Owner)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogL2OwnershipClaimed(l1TokenAddress, l2Owner);
    }

    function expectWithdrawOnL1(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.consumeMessageFromL2.selector,
            L2_KASS_ADDRESS,
            tokenDepositOnL1MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogWithdrawal(l2TokenAddress, l1TokenAddress, tokenId, amount, l1Recipient);
    }

    function expectDepositOnL2(
        address sender,
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.sendMessageToL2.selector,
            L2_KASS_ADDRESS,
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient)
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // mock message sending return value
        vm.mockCall(
            _starknetMessagingAddress,
            messageCalldata,
            abi.encode(bytes32(0), uint256(nonce))
        );

        // expect event
        address l1TokenAddress = _kass.computeL1TokenAddress(l2TokenAddress);

        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDeposit(sender, l2TokenAddress, l1TokenAddress, tokenId, amount, l2Recipient);
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancelRequest(
        address sender,
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.startL1ToL2MessageCancellation.selector,
            L2_KASS_ADDRESS,
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDepositCancelRequest(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }

    // cannot test nonce logic since it's handled by the starknet messaging contract.
    function expectDepositCancel(
        address sender,
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient,
        uint256 nonce
    ) internal {
        bytes memory messageCalldata = abi.encodeWithSelector(
            IStarknetMessaging.cancelL1ToL2Message.selector,
            L2_KASS_ADDRESS,
            DEPOSIT_HANDLER_SELECTOR,
            tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient),
            nonce
        );

        // expect L1 message send
        vm.expectCall(_starknetMessagingAddress, messageCalldata);

        // expect event
        vm.expectEmit(true, true, true, true, address(_kass));
        emit LogDepositCancel(sender, l2TokenAddress, tokenId, amount, l2Recipient, nonce);
    }
}
