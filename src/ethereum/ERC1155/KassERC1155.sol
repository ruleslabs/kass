// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

// modified version of the oz ERC1155 without constructor for a consistent bytecode
contract KassERC1155 is ERC1155 {
    address public _deployer;

    bool private _initialized = false;

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC1155("") { }

    /**
     * @dev Throws if called by any account other than the deployer.
     */
    modifier onlyDeployer() {
        require(_deployer == msg.sender, "Caller is not the deployer");
        _;
    }

    /**
     * @dev Throws if contract is already initialized.
     */
    modifier notInitialized() {
        require(!_initialized, "Can only init once");
        _;
    }

    // init
    function init(string calldata uri_) public notInitialized {
        _initialized = true;
        _deployer = msg.sender;
        _setURI(uri_);
    }

    // set uri
    function setURI(string calldata uri_) public onlyDeployer {
        _setURI(uri_);
    }

    // mint
    function mint(address to, uint256 id, uint256 amount) public onlyDeployer {
        _mint(to, id, amount, "");
    }
}
