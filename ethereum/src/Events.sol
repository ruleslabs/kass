// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract KassEvents {

    event LogWrapperCreation(uint256 indexed l2TokenAddress, address indexed l1TokenAddress);

    event LogWrapperRequest(address indexed l1TokenAddress);

    event LogOwnershipClaim(
        uint256 indexed l2TokenAddress,
        address l1TokenAddress,
        address l1Owner
    );

    event LogOwnershipRequest(
        address indexed l1TokenAddress,
        uint256 l2Owner
    );

    event LogDeposit(
        bytes32 indexed nativeTokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount
    );

    event LogWithdraw(
        bytes32 indexed nativeTokenAddress,
        address indexed recipient,
        uint256 tokenId,
        uint256 amount
    );

    event LogDepositCancelRequest(
        bytes32 indexed nativeTokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    );
    event LogDepositCancel(
        bytes32 indexed nativeTokenAddress,
        address indexed sender,
        uint256 indexed recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    );
}
