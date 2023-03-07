
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./libraries/CustomStorageSlot.sol";
import "./interfaces/IStarknetMessaging.sol";

contract KassStorage {

    // STORAGE SLOTS

    bytes32 private constant _STARKNET_MESSAGING_SLOT = keccak256("starknetMessaging");
    bytes32 private constant _L2_KASS_ADDRESS_SLOT = keccak256("l2KassAddress");
    bytes32 private constant _BASE_TOKEN_SLOT = keccak256("baseToken");
    bytes32 private constant _INITIALIZED_IMPLEMENTATIONS_SLOT = keccak256("initializedImplementations");
    bytes32 private constant _DEPOSITORS = keccak256("depositors");

    // GETTERS

    function _starknetMessaging() internal view returns (IStarknetMessaging) {
        return IStarknetMessaging(CustomStorageSlot.getAddressSlot(_STARKNET_MESSAGING_SLOT).value);
    }

    function _l2KassAddress() internal view returns (uint256) {
        return CustomStorageSlot.getUint256Slot(_L2_KASS_ADDRESS_SLOT).value;
    }

    function _baseToken() internal view returns (address) {
        return CustomStorageSlot.getAddressSlot(_BASE_TOKEN_SLOT).value;
    }

    function _initializedImplementations() internal pure returns (mapping(address => bool) storage) {
        return CustomStorageSlot.getAddressToBoolMappingSlot(_INITIALIZED_IMPLEMENTATIONS_SLOT);
    }

    function _depositors() internal pure returns (mapping(uint256 => address) storage) {
        return CustomStorageSlot.getUint256ToAddressMappingSlot(_DEPOSITORS);
    }

    // SETTERS

    function _starknetMessaging(IStarknetMessaging contract_) internal {
        CustomStorageSlot.getAddressSlot(_STARKNET_MESSAGING_SLOT).value = address(contract_);
    }

    function _l2KassAddress(uint256 value) internal {
        CustomStorageSlot.getUint256Slot(_L2_KASS_ADDRESS_SLOT).value = value;
    }

    function _baseToken(address value) internal {
        CustomStorageSlot.getAddressSlot(_BASE_TOKEN_SLOT).value = value;
    }

    function _initializedImplementations(address implementation, bool initialized) internal {
        CustomStorageSlot.getAddressToBoolMappingSlot(_INITIALIZED_IMPLEMENTATIONS_SLOT)[implementation] = initialized;
    }

    function _depositors(uint256 nonce, address depositor) internal {
        CustomStorageSlot.getUint256ToAddressMappingSlot(_DEPOSITORS)[nonce] = depositor;
    }
}
