// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

import "../src/ethereum/KassBridge.sol";
import "../src/ethereum/KassUtils.sol";
import "../src/ethereum/ERC1155/KassERC1155.sol";
import "../src/ethereum/mocks/StarknetMessagingMock.sol";

address constant STARKNET_MESSAGNING_ADDRESS = address(uint160(uint256(keccak256("starknet messaging"))));
uint256 constant L2_TOKEN_ADDRESS = uint256(keccak256("L2 token"));

contract KassBridgeTest is Test {
    KassBridge private kassBridge;
    address private starknetMessagingAddress;

    // solhint-disable-next-line var-name-mixedcase
    string[] private TOKEN_URI;
    // solhint-disable-next-line var-name-mixedcase
    uint256[] private TOKEN_URI_PAYLOAD;

    // SETUP

    function setUp() public {
        starknetMessagingAddress = address(new StarknetMessagingMock());
        kassBridge = new KassBridge(starknetMessagingAddress);

        // token uri
        TOKEN_URI = new string[](3);
        TOKEN_URI[0] = "https://api.rule";
        TOKEN_URI[1] = "s.art/metadata/{";
        TOKEN_URI[2] = "id}.json";

        // token uri payload
        TOKEN_URI_PAYLOAD = new uint256[](TOKEN_URI.length);
        for (uint8 i = 0; i < TOKEN_URI.length; ++i) {
            TOKEN_URI_PAYLOAD[i] = KassUtils.strToUint256(TOKEN_URI[i]);
        }
    }

    // HELPERS

    function createL1Instance() private returns (KassERC1155) {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_TOKEN_ADDRESS,
                TOKEN_URI_PAYLOAD
            ),
            abi.encode()
        );

        // create and return L1 instance
        return KassERC1155(kassBridge.createL1Instance(L2_TOKEN_ADDRESS, TOKEN_URI));
    }

    // TESTS

    function testL1InstanceCreation() public {
        // GIVEN
        // pre compute address
        address computedL1TokenAddress = KassUtils.computeAddress(
            address(kassBridge),
            type(KassERC1155).creationCode,
            bytes32(L2_TOKEN_ADDRESS)
        );

        // WHEN
        // create L1 instance
        KassERC1155 l1TokenInstance = createL1Instance();

        // THEN
        assertEq(computedL1TokenAddress, address(l1TokenInstance));
        assertEq(l1TokenInstance.uri(0), KassUtils.concat(TOKEN_URI));
    }
}
