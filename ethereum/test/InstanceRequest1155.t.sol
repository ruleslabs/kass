// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../src/KassUtils.sol";
import "./KassTestBase.sol";

// solhint-disable contract-name-camelcase

contract TestSetup_1155_KassInstanceRequest is KassTestBase {
    ERC1155 public _l1TokenInstance = new ERC1155(L2_TOKEN_FLAT_URI);
}

contract Test_1155_KassInstanceRequest is TestSetup_1155_KassInstanceRequest {

    function test_1155_L2TokenInstanceRequest() public {
        // pre compute address
        uint256[] memory data = KassUtils.strToFelt252Words(L2_TOKEN_FLAT_URI);

        // create L1 instance
        expectL2InstanceRequest(address(_l1TokenInstance), data, TokenStandard.ERC1155);
        _kass.requestL2Instance1155(address(_l1TokenInstance));
    }
}
