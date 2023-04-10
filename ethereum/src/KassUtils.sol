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
        bytes32 stringInBytes32 = bytes32(bytes(str));
        uint256 strLen = bytes(str).length;
        require(strLen <= 32, "String cannot be longer than 32");

        uint256 shift = 256 - 8 * strLen;

        uint256 stringInUint256;
        assembly {
            stringInUint256 := shr(shift, stringInBytes32)
        }
        return stringInUint256;
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
