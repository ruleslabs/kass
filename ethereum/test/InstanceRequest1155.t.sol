// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../src/KassUtils.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassWrapperRequest is KassTestBase {
    ERC1155 public _l1TokenWrapper = new ERC1155(L2_TOKEN_FLAT_URI);
}

contract Test_1155_KassWrapperRequest is TestSetup_1155_KassWrapperRequest {

    function test_1155_L2TokenWrapperRequest() public {
        // pre compute address
        uint256[] memory data = KassUtils.strToFelt252Words(L2_TOKEN_FLAT_URI);

        // create L1 instance
        expectL2WrapperRequest(address(_l1TokenWrapper), data, TokenStandard.ERC1155);
        _kass.requestL2Wrapper1155(address(_l1TokenWrapper));
    }
}
