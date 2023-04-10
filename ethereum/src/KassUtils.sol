// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

enum TokenStandard {
    ERC721,
    ERC1155
}

library KassUtils {

    // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
    uint256 private constant BYTES_16_MASK = 2 ** (8 * 16) - 1;

    function strToUint256(string memory str) public pure returns (uint256 res) {
        // require(strLen <= 32, "String cannot be longer than 32");

        assembly {
            let strLen := mload(str)

            if gt(strLen, 32) {
                let ptr := mload(0x40)
                mstore(ptr, 0x8c379a000000000000000000000000000000000000000000000000000000000) // shl(229, 4594637)
                mstore(add(ptr, 0x04), 0x20)
                mstore(add(ptr, 0x24), 31)
                mstore(add(ptr, 0x44), "String cannot be longer than 32")
                revert(ptr, 0x65)
            }

            let shift := sub(256, mul(8, strLen))
            let temp := mload(add(str, 0x20))
            res := shr(shift, temp)
        }
    }

    function encodeTightlyPacked(string[] calldata arr) public pure returns (bytes memory encoded) {
        for (uint256 i = 0; i < arr.length; ++i) {
            encoded = abi.encodePacked(encoded, arr[i]);
        }
    }

    function strToUint128Words(string memory str) public pure returns (uint128[] memory res) {
        assembly {
            // get str len
            let strLen := mload(str)
            let resLen := div(add(strLen, 0xf), 0x10)

            let needsFinalWordShift := not(iszero(mod(strLen, 0x10)))

            // init res
            res := mload(0x40)

            for
                {
                    let strIndex := 0x10 // 0x20 - 0x10
                    let resIndex := 0
                    let temp
                    let shift
                }
                lt(resIndex, resLen)
                {
                    strIndex := add(strIndex, 0x10)
                    resIndex := add(resIndex, 1)
                }
            {
                temp := mload(add(str, strIndex))
                if and(eq(add(resIndex, 1), resLen), needsFinalWordShift) {
                    shift := sub(128, mul(8, mod(strLen, 0x10)))
                    temp := shr(shift, and(temp, BYTES_16_MASK))
                }

                mstore(add(res, add(0x20, mul(resIndex, 0x20))), temp)
            }

            mstore(res, resLen)
            mstore(0x40, add(res, add(0x20, mul(resLen, 0x20))))
        }
    }
}
