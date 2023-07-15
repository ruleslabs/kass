// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/Utils.sol";

contract TestKassUtils is Test {

    // FELT 252 WORDS TO STR

    function testConcatMulitpleStrings() public {
        string[] memory arr = new string[](4);
        arr[0] = "Hello";
        arr[1] = " w";
        arr[2] = "orld";
        arr[3] = " !";

        assertEq(string(KassUtils.felt252WordsToStr(arr)), "Hello world !");
    }

    function testConcatSingleString() public {
        string[] memory arr;

        arr = new string[](1);
        arr[0] = "42";

        assertEq(string(KassUtils.felt252WordsToStr(arr)), "42");
    }

    function testConcatNothing() public {
        string[] memory arr = new string[](0);

        assertEq(string(KassUtils.felt252WordsToStr(arr)), "");
    }

    // FELT252 TO STR

    function testBasicFelt252ToStr() public {
        string memory res = KassUtils.felt252ToStr(0x48656C6C6F20776F726C642021);

        assertEq(res, "Hello world !");
    }

    function testZeroFelt252ToStr() public {
        string memory res = KassUtils.felt252ToStr(0x0);

        assertEq(res, "");
    }

    // STR TO FELT252

    function testBasicStrToUint256() public {
        uint256 res;

        res = KassUtils.strToFelt252("Hello world !");
        assertEq(res, 0x48656C6C6F20776F726C642021);
    }

    function testEmptyStrToUint256() public {
        uint256 res;

        res = KassUtils.strToFelt252("");
        assertEq(res, 0);
    }

    function testTooLongStrToUint256() public {
        vm.expectRevert(bytes("String cannot be longer than 31"));
        KassUtils.strToFelt252("12345678901234567890123456789012");
    }

    // STR TO FELT252 WORDS

    function testBasicStrToStr32Words_1() public {
        uint256[] memory res = KassUtils.strToFelt252Words(
            "123456789012345678901234567890-098765432109876543210987654321-1234567890"
        );

        assertEq(res.length, 3);
        assertEq(res[0], KassUtils.strToFelt252("123456789012345678901234567890-"));
        assertEq(res[1], KassUtils.strToFelt252("098765432109876543210987654321-"));
        assertEq(res[2], KassUtils.strToFelt252("1234567890"));
    }

    function testBasicStrToStr32Words_2() public {
        uint256[] memory res = KassUtils.strToFelt252Words("123456789012345678901234567890-");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToFelt252("123456789012345678901234567890-"));
    }

    function testBasicStrToStr32Words_3() public {
        uint256[] memory res = KassUtils.strToFelt252Words("");

        assertEq(res.length, 0);
    }

    function testBasicStrToStr32Words_4() public {
        uint256[] memory res = KassUtils.strToFelt252Words("123456789012345678901234567890-a");

        assertEq(res.length, 2);
        assertEq(res[0], KassUtils.strToFelt252("123456789012345678901234567890-"));
        assertEq(res[1], KassUtils.strToFelt252("a"));
    }

    function testBasicStrToStr32Words_5() public {
        uint256[] memory res = KassUtils.strToFelt252Words("123456789012345678901234567890");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToFelt252("123456789012345678901234567890"));
    }

    function testBasicStrToStr32Words_6() public {
        uint256[] memory res = KassUtils.strToFelt252Words("1");

        assertEq(res.length, 1);
        assertEq(res[0], KassUtils.strToFelt252("1"));
    }
    function testBasicStrToStr32Words_7() public {
        uint256[] memory res = KassUtils.strToFelt252Words(
            "123456789012345678901234567890-098765432109876543210987654321-"
        );

        assertEq(res.length, 2);
        assertEq(res[0], KassUtils.strToFelt252("123456789012345678901234567890-"));
        assertEq(res[1], KassUtils.strToFelt252("098765432109876543210987654321-"));
    }
}
