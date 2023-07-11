use core::zeroable::Zeroable;
use array::SpanSerde;

#[starknet::interface]
trait IKassERC721<TContractState> {
  fn initialize(ref self: TContractState, name_: felt252, symbol_: felt252, bridge_: starknet::ContractAddress);

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, token_id: u256);

  fn permissioned_burn(ref self: TContractState, token_id: u256);
}

#[starknet::interface]
trait KassERC721ABI<TContractState> {

  // ERC721 ABI

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

  fn supports_interface(self: @TContractState, interface_id: u32) -> bool;

  // Kass

  fn initialize(ref self: TContractState, name_: felt252, symbol_: felt252);

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, token_id: u256);

  fn permissioned_burn(ref self: TContractState, token_id: u256);
}

#[starknet::contract]
mod KassERC721 {
  use array::{ SpanSerde, ArrayTrait };
  use zeroable::Zeroable;
  use rules_erc721::erc721::erc721;
  use rules_erc721::erc721::erc721::ERC721;
  use rules_erc721::erc721::erc721::ERC721::{ HelperTrait as ERC721HelperTrait };
  use rules_erc721::erc721::interface::IERC721;
  use rules_erc721::introspection::erc165::{ IERC165 as rules_erc721_IERC165 };

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _bridge: starknet::ContractAddress,
  }

  //
  // Modifiers
  //

  #[generate_trait]
  impl ModifierImpl of ModifierTrait {
    fn _initializer(ref self: ContractState, bridge_: starknet::ContractAddress) {
      assert(self._bridge.read().is_zero(), 'Kass721: Already initialized');

      self._bridge.write(bridge_);
    }

    fn _only_bridge(self: @ContractState) {
      let bridge_ = self._bridge.read();
      let caller = starknet::get_caller_address();

      assert(caller.is_non_zero(), 'Caller is the zero address');
      assert(caller == bridge_, 'Caller is not the bridge');
    }
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState) { }

  //
  // IKassERC721
  //

  #[external(v0)]
  impl IKassERC721Impl of super::IKassERC721<ContractState> {
    fn initialize(ref self: ContractState, name_: felt252, symbol_: felt252, bridge_: starknet::ContractAddress) {
      // Modifiers
      self._initializer(:bridge_);

      // Body
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.initializer(:name_, :symbol_);
    }

    fn permissioned_mint(ref self: ContractState, to: starknet::ContractAddress, token_id: u256) {
      // Modifiers
      self._only_bridge();

      // Body
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self._mint(:to, :token_id);
    }

    fn permissioned_burn(ref self: ContractState, token_id: u256) {
      // Modifiers
      self._only_bridge();

      // Body
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self._burn(:token_id);
    }
  }

  //
  // ERC721 ABI impl
  //

  #[external(v0)]
  impl IERC721Impl of erc721::ERC721ABI<ContractState> {

    // IERC721

    fn name(self: @ContractState) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.name()
    }

    fn symbol(self: @ContractState) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.symbol()
    }

    fn balance_of(self: @ContractState, account: starknet::ContractAddress) -> u256 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.balance_of(:account)
    }

    fn owner_of(self: @ContractState, token_id: u256) -> starknet::ContractAddress {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.owner_of(:token_id)
    }

    fn get_approved(self: @ContractState, token_id: u256) -> starknet::ContractAddress {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.get_approved(:token_id)
    }

    fn is_approved_for_all(
      self: @ContractState,
      owner: starknet::ContractAddress,
      operator: starknet::ContractAddress
    ) -> bool {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.is_approved_for_all(:owner, :operator)
    }

    fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.token_uri(:token_id)
    }

    fn approve(ref self: ContractState, to: starknet::ContractAddress, token_id: u256) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.approve(:to, :token_id);
    }

    fn transfer_from(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      token_id: u256
    ) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.transfer_from(:from, :to, :token_id);
    }

    fn safe_transfer_from(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      token_id: u256,
      data: Span<felt252>
    ) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.safe_transfer_from(:from, :to, :token_id, :data);
    }

    fn set_approval_for_all(ref self: ContractState, operator: starknet::ContractAddress, approved: bool) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.set_approval_for_all(:operator, :approved);
    }

    // IERC165

    fn supports_interface(self: @ContractState, interface_id: u32) -> bool {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.supports_interface(:interface_id)
    }
  }

  //
  // Helpers
  //

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.initializer(:name_, :symbol_);

      let caller = starknet::get_caller_address();
      self._bridge.write(caller);
    }
  }
}
