// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./utils/Constants.sol";
import "./utils/TestBase.sol";

// solhint-disable contract-name-camelcase

contract TestKassERC721 is KassTestBase {

    //
    // Tests
    //

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
}
