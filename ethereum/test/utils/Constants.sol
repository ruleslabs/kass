// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "../../src/factory/ERC721.sol";
import "../../src/factory/ERC1155.sol";
import "../../src/factory/ERC1967Proxy.sol";

// solhint-disable func-name-mixedcase

library Constants {

    // ERC 721

    function L2_TOKEN_NAME() public pure returns (string memory) {
        return "L2 Kass Token";
    }

    function L2_TOKEN_SYMBOL() public pure returns (string memory) {
        return "L2KT";
    }

    function L2_ERC721_TOKEN_CALLDATA() public pure returns (string[] memory calldata_) {
        calldata_ = new string[](2);

        calldata_[0] = L2_TOKEN_NAME();
        calldata_[1] = L2_TOKEN_SYMBOL();
    }

    // ERC 1155

    function L2_TOKEN_FLAT_URI() public pure returns (string memory) {
        return "https://api.rules.art/metadata/{id}.json";
    }

    function L2_TOKEN_URI() public pure returns (string[] memory uri) {
        uri = new string[](3);

        uri[0] = "https://api.rule";
        uri[1] = "s.art/metadata/{";
        uri[2] = "id}.json";
    }

    function L2_ERC1155_TOKEN_CALLDATA() public pure returns (string[] memory) {
        return L2_TOKEN_URI();
    }

    // Messaging

    function STARKNET_MESSAGNING_ADDRESS() public pure returns (address) {
        return address(uint160(uint256(keccak256("starknet messaging"))));
    }

    function L1_TO_L2_MESSAGE_FEE() public pure returns (uint256) {
        return 0x42;
    }

    function L1_TO_L2_MESSAGE_NONCE() public pure returns (uint256) {
        return 0x1;
    }

    function HUGE_L1_TO_L2_MESSAGE_NONCE() public pure returns (uint256) {
        return uint256(keccak256("0x1"));
    }

    // L2 Kass

    function L2_KASS_ADDRESS() public pure returns (uint256) {
        return uint256(keccak256("L2 Kass"));
    }

    function L2_TOKEN_ADDRESS() public pure returns (uint256) {
        return uint256(keccak256("L2 token"));
    }

    function L2_RANDO_1() public pure returns (uint256) {
        return uint256(keccak256("rando 1")) % CAIRO_FIELD_PRIME();
    }

    // Cairo

    function CAIRO_FIELD_PRIME() public pure returns (uint256) {
        return 0x800000000000011000000000000000000000000000000000000000000000001;
    }

    // Tokens

    function TOKEN_ID() public pure returns (uint256) {
        return 0x1;
    }

    function TOKEN_AMOUNT() public pure returns (uint256) {
        return 0x42;
    }

    function TOKEN_AMOUNT_TO_DEPOSIT() public pure returns (uint256) {
        return TOKEN_AMOUNT() / 2;
    }

    function HUGE_TOKEN_ID() public pure returns (uint256) {
        return uint256(keccak256("0x1"));
    }

    function HUGE_TOKEN_AMOUNT() public pure returns (uint256) {
        return uint256(keccak256("0x42"));
    }

    function HUGE_TOKEN_AMOUNT_TO_DEPOSIT() public pure returns (uint256) {
        return HUGE_TOKEN_AMOUNT() / 2;
    }

    // Accounts

    function RANDO_1() public pure returns (address) {
        return address(uint160(uint256(keccak256("rando 1"))));
    }
}
