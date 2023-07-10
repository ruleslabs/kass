use starknet::ContractAddress;
use rules_erc721::erc721;
use rules_erc1155::erc1155;

use kass::introspection::erc165::{ IERC165Dispatcher, IERC165DispatcherTrait };

#[generate_trait]
impl ContractAddressInterfacesImpl of ContractAddressInterfacesTrait {
  fn isERC721(self: ContractAddress) -> bool {
    return IERC165Dispatcher { contract_address: self }.supports_interface(erc721::interface::IERC721_ID);
  }

  fn isERC1155(self: ContractAddress) -> bool {
    return IERC165Dispatcher { contract_address: self }.supports_interface(erc1155::interface::IERC1155_ID);
  }
}

#[derive(Copy, Drop)]
enum TokenStandard {
  ERC721: (),
  ERC1155: ()
}
