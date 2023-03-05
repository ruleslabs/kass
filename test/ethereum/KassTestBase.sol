// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../src/ethereum/KassBridge.sol";
import "../../src/ethereum/KassUtils.sol";
import "../../src/ethereum/ERC1155/KassERC1155.sol";
import "../../src/ethereum/mocks/StarknetMessagingMock.sol";
import "../../src/ethereum/KassMessagingPayloads.sol";
import "../../src/ethereum/StarknetConstants.sol";

abstract contract KassTestBase is Test, StarknetConstants, KassMessagingPayloads {
    KassBridge internal _kassBridge;
    address internal _starknetMessagingAddress;

    // solhint-disable-next-line var-name-mixedcase
    string[] internal L2_TOKEN_URI;

    address internal constant STARKNET_MESSAGNING_ADDRESS = address(uint160(uint256(keccak256("starknet messaging"))));
    uint256 internal constant L2_KASS_ADDRESS = uint256(keccak256("L2 Kass"));
    uint256 internal constant L2_TOKEN_ADDRESS = uint256(keccak256("L2 token"));

    uint256 public constant CAIRO_FIELD_PRIME = 0x800000000000011000000000000000000000000000000000000000000000001;

    constructor () {
        // L2 token uri
        L2_TOKEN_URI = new string[](3);
        L2_TOKEN_URI[0] = "https://api.rule";
        L2_TOKEN_URI[1] = "s.art/metadata/{";
        L2_TOKEN_URI[2] = "id}.json";
    }

    // SETUP

    function setUp() public virtual {
        // setup starknet messaging mock
        _starknetMessagingAddress = address(new StarknetMessagingMock());

        // setup bridge
        _kassBridge = new KassBridge(_starknetMessagingAddress);
        _kassBridge.setL2KassAddress(L2_KASS_ADDRESS);
    }

    // MESSAGES

    function requestL1InstanceCreation(uint256 l2TokenAddress, string[] memory uri) internal {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                instanceCreationMessagePayload(l2TokenAddress, uri)
            ),
            abi.encode()
        );
    }

    function depositFromL2(uint256 l2TokenAddress, uint256 tokenId, uint256 amount, address l1Recipient) internal {
        // prepare L1 instance deposit message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                tokenDepositFromL2MessagePayload(l2TokenAddress, tokenId, amount, l1Recipient)
            ),
            abi.encode()
        );
    }

    function expectDepositFromL2(
        uint256 l2TokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 l2Recipient
    ) internal {
        // expect L1 message send
        vm.expectCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.sendMessageToL2.selector,
                L2_KASS_ADDRESS,
                DEPOSIT_HANDLER_SELECTOR,
                tokenDepositOnL2MessagePayload(l2TokenAddress, tokenId, amount, l2Recipient)
            )
        );
    }
}
