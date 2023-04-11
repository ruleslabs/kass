// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

enum TokenStandard {
    ERC721,
    ERC1155
}

library KassUtils {

    // 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    uint256 private constant BYTES_31_MASK = 2 ** (8 * 31) - 1;

    function strToFelt252(string memory str) public pure returns (uint256 res) {
        assembly {
            let strLen := mload(str)

            if gt(strLen, 31) {
                let ptr := mload(0x40)
                mstore(ptr, 0x8c379a000000000000000000000000000000000000000000000000000000000) // shl(229, 4594637)
                mstore(add(ptr, 0x04), 0x20)
                mstore(add(ptr, 0x24), 31)
                mstore(add(ptr, 0x44), "String cannot be longer than 31")
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

    function strToFelt252Words(string memory str) public pure returns (uint256[] memory res) {
        assembly {
            // get str len
            let strLen := mload(str)
            let resLen := div(add(strLen, 0x1e), 0x1f)

            let needsFinalWordShift := not(iszero(mod(strLen, 0x1f)))

            // init res
            res := mload(0x40)

            for
                {
                    let strIndex := 0x1f
                    let resIndex := 0
                    let temp
                }
                lt(resIndex, resLen)
                {
                    strIndex := add(strIndex, 0x1f)
                    resIndex := add(resIndex, 1)
                }
            {
                temp := and(mload(add(str, strIndex)), BYTES_31_MASK)
                if and(eq(add(resIndex, 1), resLen), needsFinalWordShift) {
                    temp := shr(sub(248, mul(8, mod(strLen, 0x1f))), temp)
                }

                mstore(add(res, add(0x20, mul(resIndex, 0x20))), temp)
            }

            mstore(res, resLen)
            mstore(0x40, add(res, add(0x20, mul(resLen, 0x20))))
        }
    }
}
