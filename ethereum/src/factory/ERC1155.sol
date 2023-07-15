// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// modified version of the oz ERC1155 without constructor for a consistent bytecode
contract KassERC1155 is Context, ERC1155, Ownable, UUPSUpgradeable {

    bool private _initialized = false;

    address private _bridge;

    //
    // Modifiers
    //

    modifier initializer() {
        address implementation = _getImplementation();

        require(!_initialized, "Kass1155: Already initialized");
        _initialized = true;

        _;
    }

    modifier onlyBridge() {
        require(_bridge == _msgSender(), "Kass1155: Not bridge");

        _;
    }

    //
    // Constructor
    //

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC1155("") { }

    function initialize(bytes calldata data) public initializer {
        (string memory uri_) = abi.decode(data, (string));

        _setURI(uri_);

        _setBridge();
        _transferOwnership(_msgSender());
    }

    //
    // Upgrade
    //

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    //
    // Kass ERC 1155
    //

    // upgrade
    function permissionedUpgradeTo(address newImplementation) public onlyBridge {
        _upgradeTo(newImplementation);
    }

    // mint
    function permissionedMint(address to, uint256 id, uint256 amount) public onlyBridge {
        _mint(to, id, amount, "");
    }

    // burn
    function permissionedBurn(address from, uint256 id, uint256 amount) public onlyBridge {
        _burn(from, id, amount);
    }

    //
    // Internals
    //

    function _setBridge() private {
        _bridge = _msgSender();
    }
}
