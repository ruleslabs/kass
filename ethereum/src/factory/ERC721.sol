// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// modified version of the oz ERC1155 without constructor for a consistent bytecode
contract KassERC721 is Context, ERC721, Ownable, UUPSUpgradeable {

    bool private _initialized = false;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    address private _bridge;

    //
    // Modifiers
    //

    modifier initializer() {
        address implementation = _getImplementation();

        require(!_initialized, "Kass721: Already initialized");
        _initialized = true;

        _;
    }

    modifier onlyBridge() {
        require(_bridge == _msgSender(), "Kass721: Not bridge");

        _;
    }

    //
    // Constructor
    //

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC721("", "") { }

    function initialize(bytes calldata data) public initializer {
        (string memory name_, string memory symbol_) = abi.decode(data, (string, string));

        _name = name_;
        _symbol = symbol_;

        _setBridge();
        _transferOwnership(_msgSender());
    }

    //
    // Upgrade
    //

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    //
    // Kass ERC 721
    //

    // upgrade
    function permissionedUpgradeTo(address newImplementation) public onlyBridge {
        _upgradeTo(newImplementation);
    }

    // mint
    function permissionedMint(address to, uint256 tokenId) public onlyBridge {
        _mint(to, tokenId);
    }

    // burn
    function permissionedBurn(uint256 id) public onlyBridge {
        _burn(id);
    }

    //
    // ERC721 Metadata
    //

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    //
    // Internals
    //

    function _setBridge() private {
        _bridge = _msgSender();
    }
}
