// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.19;

/**
 * Modified https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/StorageSlot.sol
 * to support more types.
 */
library CustomStorageSlot {
    struct AddressSlot {
        address value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `mapping(address => bool)` with member `value` located at `slot`.
     */
    function getAddressToBoolMappingSlot(
        bytes32 slot
    ) internal pure returns (mapping(address => bool) storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `mapping(uint256 => address)` with member `value` located at `slot`.
     */
    function getUint256ToAddressMappingSlot(
        bytes32 slot
    ) internal pure returns (mapping(uint256 => address) storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}
