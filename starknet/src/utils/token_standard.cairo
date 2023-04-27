use starknet::ContractAddress;

use kass::interfaces::IERC165::IERC165Dispatcher;
use kass::interfaces::IERC165::IERC165DispatcherTrait;

use kass::interfaces::IERC721::IERC721_ID;
use kass::interfaces::IERC1155::IERC1155_ID;

trait ContractAddressInterfacesTrait {
    fn isERC721(self: ContractAddress) -> bool;
    fn isERC1155(self: ContractAddress) -> bool;
}

impl ContractAddressInterfacesImpl of ContractAddressInterfacesTrait {
    fn isERC721(self: ContractAddress) -> bool {
        return IERC165Dispatcher { contract_address: self }.supports_interface(IERC721_ID);
    }

    fn isERC1155(self: ContractAddress) -> bool {
        return IERC165Dispatcher { contract_address: self }.supports_interface(IERC1155_ID);
    }
}

#[derive(Copy, Drop)]
enum TokenStandard {
    ERC721: (),
    ERC1155: ()
}
