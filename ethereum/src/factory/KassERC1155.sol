// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// modified version of the oz ERC1155 without constructor for a consistent bytecode
contract KassERC1155 is ERC1155, Ownable, UUPSUpgradeable {

    bool private _initialized = false;

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC1155("") { }

    // MODIFIERS

    modifier initializer() {
        address implementation = _getImplementation();

        require(!_initialized, "Already initialized");
        _initialized = true;

        _;
    }

    // INIT

    function initialize(bytes calldata data) public initializer {
        (string memory uri_) = abi.decode(data, (string));

        _setURI(uri_);

        _transferOwnership(msg.sender);
    }

    // UPGRADE

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    // MINT & BURN

    // mint
    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }

    // burn
    function burn(address from, uint256 id, uint256 amount) public onlyOwner {
        _burn(from, id, amount);
    }
}
