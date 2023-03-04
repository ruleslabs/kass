// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ethereum/KassUtils.sol";

contract KassUtilsTest is Test {
    function setUp() public {
        // solhint-disable-previous-line no-empty-blocks
    }

    // CONCAT
    function testConcatMulitpleStrings() public {
        string memory res;
        string[] memory arr;

        arr = new string[](4);
        arr[0] = "Hello";
        arr[1] = " w";
        arr[2] = "orld";
        arr[3] = " !";

        res = KassUtils.concat(arr);
        assertEq(res, "Hello world !");
    }

    function testConcatSingleString() public {
        string memory res;
        string[] memory arr;

        arr = new string[](1);
        arr[0] = "42";

        res = KassUtils.concat(arr);
        assertEq(res, "42");
    }

    function testConcatNothing() public {
        string memory res;
        string[] memory arr;

        arr = new string[](0);

        res = KassUtils.concat(arr);
        assertEq(res, "");
    }

    // STR TO UINT256
    function testBasicStrToUint256() public {
        uint256 res;

        res = KassUtils.strToUint256("Hello world !");
        assertEq(res, uint256(0x48656C6C6F20776F726C642021));
    }

    function testEmptyStrToUint256() public {
        uint256 res;

        res = KassUtils.strToUint256("");
        assertEq(res, uint256(0x0));
    }

    function testTooLongStrToUint256() public {
        vm.expectRevert(bytes("String cannot be longer than 32"));
        KassUtils.strToUint256("123456789012345678901234567890123");
    }
}
