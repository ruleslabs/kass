use array::SpanSerde;

#[starknet::interface]
trait KassERC721ABI<TContractState> {
  fn name(self: @TContractState) -> felt252;

  fn symbol(self: @TContractState) -> felt252;

  fn balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;

  fn owner_of(self: @TContractState, token_id: u256) -> starknet::ContractAddress;

  fn get_approved(self: @TContractState, token_id: u256) -> starknet::ContractAddress;

  fn is_approved_for_all(
    self: @TContractState,
    owner: starknet::ContractAddress,
    operator: starknet::ContractAddress
  ) -> bool;

  fn token_uri(self: @TContractState, token_id: u256) -> felt252;

  fn approve(ref self: TContractState, to: starknet::ContractAddress, token_id: u256);

  fn transfer_from(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    token_id: u256
  );

  fn safe_transfer_from(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    token_id: u256,
    data: Span<felt252>
  );

  fn set_approval_for_all(ref self: TContractState, operator: starknet::ContractAddress, approved: bool);

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, token_id: u256);

  fn permissioned_burn(ref self: TContractState, token_id: u256);
}

#[starknet::contract]
mod KassERC721 {

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _deployer: starknet::ContractAddress,
  }

  //
  // Modifiers
  //

  #[generate_trait]
  impl ModifierImpl of ModifierTrait {
    fn _only_deployer(self: @ContractState) {
      let caller = starknet::get_caller_address();

      assert(caller == self._deployer.read(), 'Kass1155: Not deployer');
    }
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState) {

  }

  //
  // Helpers
  //

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn initializer(ref self: ContractState) {
      let caller = starknet::get_caller_address();

      assert(caller == self._deployer.read(), 'Kass1155: Not deployer');
    }
  }
}
