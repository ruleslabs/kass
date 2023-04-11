// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../src/KassUtils.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_721_KassInstanceRequest is KassTestBase {
    ERC721 public _l1TokenInstance = new ERC721(L2_TOKEN_NAME, L2_TOKEN_SYMBOL);
}

contract Test_721_KassInstanceRequest is TestSetup_721_KassInstanceRequest {

    function test_721_L2TokenInstanceRequest() public {
        // pre compute address
        uint256[] memory data = new uint256[](2);

        data[0] = KassUtils.strToFelt252(L2_TOKEN_NAME);
        data[1] = KassUtils.strToFelt252(L2_TOKEN_SYMBOL);

        // create L1 instance
        expectL2InstanceRequest(address(_l1TokenInstance), data, TokenStandard.ERC721);
        _kass.requestL2Instance721(address(_l1TokenInstance));
    }
}
