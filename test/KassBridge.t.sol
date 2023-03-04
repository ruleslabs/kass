// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

import "../src/ethereum/KassBridge.sol";
import "../src/ethereum/KassUtils.sol";
import "../src/ethereum/ERC1155/KassERC1155.sol";
import "../src/ethereum/mocks/StarknetMessagingMock.sol";

address constant STARKNET_MESSAGNING_ADDRESS = address(uint160(uint256(keccak256("starknet messaging"))));
uint256 constant L2_KASS_ADDRESS = uint256(keccak256("L2 Kass"));
uint256 constant L2_TOKEN_ADDRESS = uint256(keccak256("L2 token"));

contract KassBridgeTest is Test {
    KassBridge private kassBridge;
    address private starknetMessagingAddress;

    // solhint-disable-next-line var-name-mixedcase
    string[] private L2_TOKEN_URI;
    // solhint-disable-next-line var-name-mixedcase
    uint256[] private L1_TOKEN_REQUEST_PAYLOAD;

    // SETUP

    function setUp() public {
        // setup starknet messaging mock
        starknetMessagingAddress = address(new StarknetMessagingMock());

        // setup bridge
        kassBridge = new KassBridge(starknetMessagingAddress);
        kassBridge.setL2KassAddress(L2_KASS_ADDRESS);

        // L2 token uri
        L2_TOKEN_URI = new string[](3);
        L2_TOKEN_URI[0] = "https://api.rule";
        L2_TOKEN_URI[1] = "s.art/metadata/{";
        L2_TOKEN_URI[2] = "id}.json";

        // L1 token request payload
        L1_TOKEN_REQUEST_PAYLOAD = new uint256[](L2_TOKEN_URI.length + 1);

        // load L2 token address
        L1_TOKEN_REQUEST_PAYLOAD[0] = L2_TOKEN_ADDRESS;

        // load L2 token URI
        for (uint8 i = 0; i < L2_TOKEN_URI.length; ++i) {
            L1_TOKEN_REQUEST_PAYLOAD[i + 1] = KassUtils.strToUint256(L2_TOKEN_URI[i]);
        }
    }

    // HELPERS

    function createL1Instance() private returns (KassERC1155 kassERC1155) {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                L2_KASS_ADDRESS,
                L1_TOKEN_REQUEST_PAYLOAD
            ),
            abi.encode()
        );

        // create and return L1 instance
        kassERC1155 = KassERC1155(kassBridge.createL1Instance(L2_TOKEN_ADDRESS, L2_TOKEN_URI));

        // clear mocked calls
        vm.clearMockedCalls();
    }

    // TESTS

    function testCannotUpdateL2KassAddressIfNotOwner() public {
        // THEN
        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        kassBridge.setL2KassAddress(0xdead);
    }

    function testL1TokenInstanceComputedAddress() public {
        // pre compute address
        address computedL1TokenAddress = KassUtils.computeAddress(
            address(kassBridge),
            type(KassERC1155).creationCode,
            bytes32(L2_TOKEN_ADDRESS)
        );

        // create L1 instance
        KassERC1155 l1TokenInstance = createL1Instance();

        // THEN
        assertEq(computedL1TokenAddress, address(l1TokenInstance));
    }

    function testL1TokenInstanceUri() public {
        // create L1 instance
        KassERC1155 l1TokenInstance = createL1Instance();

        // THEN
        assertEq(l1TokenInstance.uri(0), KassUtils.concat(L2_TOKEN_URI));
    }

    function testCannotUpdateL1TokenInstanceUri() public {
        // create L1 instance
        KassERC1155 l1TokenInstance = createL1Instance();

        // THEN
        vm.expectRevert("KassERC1155: URI already set");
        l1TokenInstance.setURI("foo");
    }
}
