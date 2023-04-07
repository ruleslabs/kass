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

    address private _deployer;

    // solhint-disable-next-line no-empty-blocks
    constructor() ERC721("", "") { }

    // MODIFIERS

    modifier initializer() {
        address implementation = _getImplementation();

        require(!_initialized, "Kass1155: Already initialized");
        _initialized = true;

        _;
    }

    modifier onlyDeployer() {
        require(_deployer == _msgSender(), "Kass1155: Not deployer");

        _;
    }

    // INIT

    function initialize(bytes calldata data) public initializer {
        (string memory name_, string memory symbol_) = abi.decode(data, (string, string));

        _name = name_;
        _symbol = symbol_;

        _setDeployer();
        _transferOwnership(_msgSender());
    }

    // UPGRADE

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    // GETTERS

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

    // MINT & BURN

    // mint
    function mint(address to, uint256 tokenId) public onlyDeployer {
        _mint(to, tokenId);
    }

    // burn
    function burn(uint256 id) public onlyDeployer {
        _burn(id);
    }

    // INTERNALS

    function _setDeployer() private {
        _deployer = _msgSender();
    }
}
