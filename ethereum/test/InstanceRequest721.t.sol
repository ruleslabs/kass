// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../src/KassUtils.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassWrapperRequest is KassTestBase {
    ERC721 public _l1TokenWrapper = new ERC721(L2_TOKEN_NAME, L2_TOKEN_SYMBOL);
}

contract Test_721_KassWrapperRequest is TestSetup_721_KassWrapperRequest {

    function test_721_L2TokenWrapperRequest() public {
        // create L1 instance
        expectL2WrapperRequest(address(_l1TokenWrapper));
        _kass.requestL2Wrapper(address(_l1TokenWrapper));
    }
}
