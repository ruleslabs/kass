// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../src/Messaging.sol";

import "./utils/Constants.sol";
import "./utils/TestBase.sol";

// solhint-disable contract-name-camelcase

contract MockBridge is KassMessaging {
    function parseDepositRequestMessagePayload(
        uint256[] calldata payload
    ) public pure returns (DepositRequest memory depositRequest) {
        depositRequest = _parseDepositRequestMessagePayload(payload);
    }
}

contract TestKassMessaging is KassTestBase {

    //
    // Storage
    //

    MockBridge internal _kassMessaging = new MockBridge();

    //
    // Tests
    //

    // Ownership request

    function testRequestOwnershipPayload() public {
        address l1TokenAddress = address(_erc1155);
        uint256 l2Owner = Constants.L2_RANDO_1();

        (uint256[] memory payload, uint256 handlerSelector) = _computeL2OwnershipClaimMessage(l1TokenAddress, l2Owner);

        assertEq(handlerSelector, OWNERSHIP_CLAIM_HANDLER_SELECTOR);

        assertEq(payload.length, 2);
        assertEq(payload[0], uint256(_bytes32(l1TokenAddress)));
        assertEq(payload[1], l2Owner);
    }

    // Ownership claim

    function testClaimOwnershipPayload() public {
        uint256 l2TokenAddress = Constants.L2_TOKEN_ADDRESS();
        address l1Owner = Constants.RANDO_1();

        uint256[] memory payload = _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner);

        assertEq(payload.length, 3);
        assertEq(payload[0], CLAIM_OWNERSHIP);
        assertEq(payload[1], l2TokenAddress);
        assertEq(payload[2], uint256(uint160(l1Owner)));
    }

    // Deposit

    function testDepositPayload() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        bool requestWrapper = false;

        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );

        assertEq(handlerSelector, WITHDRAW_HANDLER_SELECTOR);

        assertEq(payload.length, 6);
        assertEq(payload[0], Constants.L2_TOKEN_ADDRESS());
        assertEq(payload[1], recipient);
        assertEq(payload[2], tokenId);
        assertEq(payload[3], 0);
        assertEq(payload[4], amount);
        assertEq(payload[5], 0);
    }

    function testDepositPayloadWithHugeVariables() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        bool requestWrapper = false;

        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );

        assertEq(handlerSelector, WITHDRAW_HANDLER_SELECTOR);

        assertEq(payload.length, 6);
        assertEq(payload[0], Constants.L2_TOKEN_ADDRESS());
        assertEq(payload[1], recipient);
        assertEq(payload[2], Constants.HUGE_TOKEN_ID_LOW());
        assertEq(payload[3], Constants.HUGE_TOKEN_ID_HIGH());
        assertEq(payload[4], Constants.HUGE_TOKEN_AMOUNT_LOW());
        assertEq(payload[5], Constants.HUGE_TOKEN_AMOUNT_HIGH());
    }

    function testDepositWithERC721WrapperRequestPayload() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        uint256 recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        bool requestWrapper = true;

        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );

        assertEq(handlerSelector, WRAPPER_CREATION_AND_WITHDRAW_721_HANDLER_SELECTOR);

        assertEq(payload.length, 8);
        assertEq(payload[0], uint256(nativeTokenAddress));
        assertEq(payload[1], recipient);
        assertEq(payload[2], tokenId);
        assertEq(payload[3], 0);
        assertEq(payload[4], amount);
        assertEq(payload[5], 0);
        assertEq(payload[6], KassUtils.strToFelt252(Constants.L2_TOKEN_NAME()));
        assertEq(payload[7], KassUtils.strToFelt252(Constants.L2_TOKEN_SYMBOL()));
    }

    function testDepositWithERC1155WrapperRequestPayload() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        uint256 recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        bool requestWrapper = true;
        uint256[] memory uri = KassUtils.strToFelt252Words(Constants.L2_TOKEN_FLAT_URI());

        (uint256[] memory payload, uint256 handlerSelector) = _computeTokenDepositOnL2Message(
            nativeTokenAddress,
            recipient,
            tokenId,
            amount,
            requestWrapper
        );

        assertEq(handlerSelector, WRAPPER_CREATION_AND_WITHDRAW_1155_HANDLER_SELECTOR);

        assertEq(payload.length, 6 + uri.length);
        assertEq(payload[0], uint256(nativeTokenAddress));
        assertEq(payload[1], recipient);
        assertEq(payload[2], tokenId);
        assertEq(payload[3], 0);
        assertEq(payload[4], amount);
        assertEq(payload[5], 0);

        for (uint i = 0; i < uri.length; ++i) {
            assertEq(payload[i + 6], uri[i]);
        }
    }

    // Withdraw

    function testWithdrawPayload() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address recipient = Constants.RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();

        uint256[] memory payload = new uint256[](7);

        payload[0] = DEPOSIT_TO_L1;
        payload[1] = uint256(nativeTokenAddress);
        payload[2] = uint256(uint160(recipient));
        payload[3] = tokenId;
        payload[4] = 0;
        payload[5] = amount;
        payload[6] = 0;

        DepositRequest memory depositRequest = _kassMessaging.parseDepositRequestMessagePayload(payload);

        assertEq(depositRequest._calldata, bytes(""));
        assertEq(depositRequest.tokenStandard == TokenStandard.UNKNOWN, true);
        assertEq(depositRequest.nativeTokenAddress, nativeTokenAddress);
        assertEq(depositRequest.recipient, recipient);
        assertEq(depositRequest.tokenId, tokenId);
        assertEq(depositRequest.amount, amount);
    }

    function testWithdrawPayloadWithHugeVariables() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address recipient = Constants.RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();

        uint256[] memory payload = new uint256[](7);

        payload[0] = DEPOSIT_TO_L1;
        payload[1] = uint256(nativeTokenAddress);
        payload[2] = uint256(uint160(recipient));
        payload[3] = Constants.HUGE_TOKEN_ID_LOW();
        payload[4] = Constants.HUGE_TOKEN_ID_HIGH();
        payload[5] = Constants.HUGE_TOKEN_AMOUNT_LOW();
        payload[6] = Constants.HUGE_TOKEN_AMOUNT_HIGH();

        DepositRequest memory depositRequest = _kassMessaging.parseDepositRequestMessagePayload(payload);

        assertEq(depositRequest._calldata, bytes(""));
        assertEq(depositRequest.tokenStandard == TokenStandard.UNKNOWN, true);
        assertEq(depositRequest.nativeTokenAddress, nativeTokenAddress);
        assertEq(depositRequest.recipient, recipient);
        assertEq(depositRequest.tokenId, tokenId);
        assertEq(depositRequest.amount, amount);
    }

    function testWithdrawWithERC721WrapperRequestPayload() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address recipient = Constants.RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();

        uint256[] memory payload = new uint256[](9);

        payload[0] = DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1;
        payload[1] = uint256(nativeTokenAddress);
        payload[2] = uint256(uint160(recipient));
        payload[3] = tokenId;
        payload[4] = 0;
        payload[5] = amount;
        payload[6] = 0;
        payload[7] = KassUtils.strToFelt252(Constants.L2_TOKEN_NAME());
        payload[8] = KassUtils.strToFelt252(Constants.L2_TOKEN_SYMBOL());

        DepositRequest memory depositRequest = _kassMessaging.parseDepositRequestMessagePayload(payload);
        (string memory name, string memory symbol) = abi.decode(depositRequest._calldata, (string, string));

        assertEq(name, Constants.L2_TOKEN_NAME());
        assertEq(symbol, Constants.L2_TOKEN_SYMBOL());
        assertEq(depositRequest.tokenStandard == TokenStandard.ERC721, true);
        assertEq(depositRequest.nativeTokenAddress, nativeTokenAddress);
        assertEq(depositRequest.recipient, recipient);
        assertEq(depositRequest.tokenId, tokenId);
        assertEq(depositRequest.amount, amount);
    }

    function testWithdrawWithERC1155WrapperRequestPayload() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address recipient = Constants.RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256[] memory uri = KassUtils.strToFelt252Words(Constants.L2_TOKEN_FLAT_URI());

        uint256[] memory payload = new uint256[](7 + uri.length);

        payload[0] = DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1;
        payload[1] = uint256(nativeTokenAddress);
        payload[2] = uint256(uint160(recipient));
        payload[3] = tokenId;
        payload[4] = 0;
        payload[5] = amount;
        payload[6] = 0;

        for (uint i = 0; i < uri.length; ++i) {
            payload[i + 7] = uri[i];
        }

        DepositRequest memory depositRequest = _kassMessaging.parseDepositRequestMessagePayload(payload);
        (string memory decodedUri) = abi.decode(depositRequest._calldata, (string));

        assertEq(string(decodedUri), Constants.L2_TOKEN_FLAT_URI());
        assertEq(string(KassUtils.felt252WordsToStr(uri)), Constants.L2_TOKEN_FLAT_URI());
        assertEq(depositRequest.tokenStandard == TokenStandard.ERC1155, true);
        assertEq(depositRequest.nativeTokenAddress, nativeTokenAddress);
        assertEq(depositRequest.recipient, recipient);
        assertEq(depositRequest.tokenId, tokenId);
        assertEq(depositRequest.amount, amount);
    }
}
