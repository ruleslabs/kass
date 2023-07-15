// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/Bridge.sol";
import "../../src/TokenDeployer.sol";
import "../../src/Utils.sol";
import "../../src/Messaging.sol";
import "../../src/StarknetConstants.sol";

import "../../src/factory/ERC721.sol";
import "../../src/factory/ERC1155.sol";
import "../../src/factory/ERC1967Proxy.sol";

import "../mocks/StarknetMessagingMock.sol";
import "./Constants.sol";

contract Starknet is Test, StarknetConstants, KassMessaging {

    //
    // Storage
    //

    address internal _starknetMessagingAddress;

    //
    // Constructor
    //

    constructor(address starknetMessagingAddress_) {
        _starknetMessagingAddress = starknetMessagingAddress_;
    }

    // Ownership

    function requestOwnership(uint256 l2TokenAddress, address l1Owner) public {
        // prepare L1 instance creation message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                Constants.L2_KASS_ADDRESS(),
                _computeL1OwnershipClaimMessage(l2TokenAddress, l1Owner)
            ),
            abi.encode(bytes32(0x0))
        );
    }

    // Deposit

    function deposit(
        bytes32 nativeTokenAddress,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        bool requestWrapper
    ) public returns (uint256[] memory) {
        return _deposit(nativeTokenAddress, l1Recipient, tokenId, amount, tokenStandard, requestWrapper);
    }

    //
    // Internals
    //

    function _deposit(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        bool requestWrapper
    ) internal returns (uint256[] memory messagePayload) {
        string[] memory calldata_;

        // add wrapper creation calldata to message payload if a wrapper is requested
        if (requestWrapper) {
            if (tokenStandard == TokenStandard.ERC721) {
                calldata_ = Constants.L2_ERC721_TOKEN_CALLDATA();
            } else if (tokenStandard == TokenStandard.ERC1155) {
                calldata_ = Constants.L2_ERC1155_TOKEN_CALLDATA();
            } else {
                revert("Kass: Unknown token standard");
            }
        } else {
            calldata_ = new string[](0);
        }

        messagePayload = _computeTokenDepositOnL1Message(
            tokenAddress,
            recipient,
            tokenId,
            amount,
            tokenStandard,
            calldata_
        );

        // prepare L1 instance deposit message from L2
        vm.mockCall(
            _starknetMessagingAddress,
            abi.encodeWithSelector(
                IStarknetMessaging.consumeMessageFromL2.selector,
                Constants.L2_KASS_ADDRESS(),
                messagePayload
            ),
            abi.encode(bytes32(0x0))
        );
    }

    function _computeTokenDepositOnL1Message(
        bytes32 tokenAddress,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        TokenStandard tokenStandard,
        string[] memory calldata_
    ) internal pure returns (uint256[] memory payload) {
        if (calldata_.length > 0) {
            payload = new uint256[](calldata_.length + 7);

            if (tokenStandard == TokenStandard.ERC721) {
                payload[0] = DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1;
            } else if (tokenStandard == TokenStandard.ERC1155) {
                payload[0] = DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1;
            } else {
                revert("Kass: Unknown token standard");
            }

            // store token URI
            for (uint8 i = 0; i < calldata_.length; ++i) {
                payload[i + 7] = KassUtils.strToFelt252(calldata_[i]);
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
