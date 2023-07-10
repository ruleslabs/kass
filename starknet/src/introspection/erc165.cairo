const IERC165_ID: u32 = 0x01ffc9a7_u32;
const INVALID_ID: u32 = 0xffffffff_u32;

#[starknet::interface]
trait IERC165<TContractState> {
  fn supports_interface(self: @TContractState, interface_id: u32) -> bool;
}

#[starknet::contract]
mod ERC165 {
  // locals
  use rules_account::introspection::erc165;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    supported_interfaces: LegacyMap<u32, bool>
  }

  //
  // ERC165 impl
  //

  #[external(v0)]
  impl ERC165Impl of erc165::IERC165<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: u32) -> bool {
      if interface_id == erc165::IERC165_ID {
        return true;
      }
      self.supported_interfaces.read(interface_id)
    }
  }

  //
  // Internal
  //

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn register_interface(ref self: ContractState, interface_id: u32) {
      assert(interface_id != erc165::INVALID_ID, 'Invalid id');
      self.supported_interfaces.write(interface_id, true);
    }

    fn deregister_interface(ref self: ContractState, interface_id: u32) {
      assert(interface_id != erc165::IERC165_ID, 'Invalid id');
      self.supported_interfaces.write(interface_id, false);
    }
  }
}
