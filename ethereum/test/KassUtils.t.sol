// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/KassUtils.sol";

// solhint-disable contract-name-camelcase

contract Test_KassUtils is Test {

    // ENCODE TIGHTY PACKED
    function test_ConcatMulitpleStrings() public {
        string[] memory arr = new string[](4);
        arr[0] = "Hello";
        arr[1] = " w";
        arr[2] = "orld";
        arr[3] = " !";

        assertEq(string(KassUtils.encodeTightlyPacked(arr)), "Hello world !");
    }

    function test_ConcatSingleString() public {
        string[] memory arr;

        arr = new string[](1);
        arr[0] = "42";

        assertEq(string(KassUtils.encodeTightlyPacked(arr)), "42");
    }

    function test_ConcatNothing() public {
        string[] memory arr = new string[](0);

        assertEq(string(KassUtils.encodeTightlyPacked(arr)), "");
    }

    // STR TO UINT256
    function test_BasicStrToUint256() public {
        uint256 res;

        res = KassUtils.strToUint256("Hello world !");
        assertEq(res, uint256(0x48656C6C6F20776F726C642021));
    }

    function test_EmptyStrToUint256() public {
        uint256 res;

        res = KassUtils.strToUint256("");
        assertEq(res, uint256(0x0));
    }

    function test_TooLongStrToUint256() public {
        vm.expectRevert(bytes("String cannot be longer than 32"));
        KassUtils.strToUint256("123456789012345678901234567890123");
    }

    // STR TO STR 32 WORDS
    function test_BasicStrToStr32Words_1() public {
        uint128[] memory res = KassUtils.strToUint128Words("1234567890123456789012345678901234567890");

        assertEq(res.length, 3);
        assertEq(res[0], KassUtils.strToUint256("1234567890123456"));
        assertEq(res[1], KassUtils.strToUint256("7890123456789012"));
        assertEq(res[2], KassUtils.strToUint256("34567890"));
    }

    function test_BasicStrToStr32Words_2() public {
        uint128[] memory res = KassUtils.strToUint128Words("1234567890123456");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToUint256("1234567890123456"));
    }

    function test_BasicStrToStr32Words_3() public {
        uint128[] memory res = KassUtils.strToUint128Words("");

        assertEq(res.length, 0);
    }

    function test_BasicStrToStr32Words_4() public {
        uint128[] memory res = KassUtils.strToUint128Words("12345678901234567");

        assertEq(res.length, 2);
        assertEq(res[0], KassUtils.strToUint256("1234567890123456"));
        assertEq(res[1], KassUtils.strToUint256("7"));
    }

    function test_BasicStrToStr32Words_5() public {
        uint128[] memory res = KassUtils.strToUint128Words("123456789012345");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToUint256("123456789012345"));
    }

    function test_BasicStrToStr32Words_6() public {
        uint128[] memory res = KassUtils.strToUint128Words("1");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToUint256("1"));
    }
    function test_BasicStrToStr32Words_7() public {
        uint128[] memory res = KassUtils.strToUint128Words("12345678901234567890123456789012");

        assertEq(res.length, 2);
        assertEq(res[0], KassUtils.strToUint256("1234567890123456"));
        assertEq(res[1], KassUtils.strToUint256("7890123456789012"));
    }
}
