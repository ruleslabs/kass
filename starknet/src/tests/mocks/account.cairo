//
// Account
//

#[starknet::contract]
mod Account {
  use rules_utils::introspection::interface::ISRC5;
  use rules_account::account::interface::ISRC6_ID;

  #[storage]
  struct Storage { }

  #[external(v0)]
  impl ISRC5Impl of ISRC5<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      interface_id == ISRC6_ID
    }
  }
}
