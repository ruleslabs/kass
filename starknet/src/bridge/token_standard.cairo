use starknet::ContractAddress;
use rules_erc721::erc721::interface::IERC721_ID;
use rules_erc1155::erc1155::interface::IERC1155_ID;

// Dispatchers
use rules_utils::introspection::dual_src5::{ DualCaseSRC5, DualCaseSRC5Trait };

#[generate_trait]
impl ContractAddressInterfacesImpl of ContractAddressInterfacesTrait {
  fn isERC721(self: ContractAddress) -> bool {
    return DualCaseSRC5 { contract_address: self }.supports_interface(IERC721_ID);
  }

  fn isERC1155(self: ContractAddress) -> bool {
    return DualCaseSRC5 { contract_address: self }.supports_interface(IERC1155_ID);
  }
}

#[derive(Copy, Drop)]
enum TokenStandard {
  ERC721: (),
  ERC1155: ()
}
