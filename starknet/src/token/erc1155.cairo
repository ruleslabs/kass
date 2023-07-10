use array::SpanSerde;

#[starknet::interface]
trait IKassERC1155<TContractState> {
  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, id: u256, amount: u256);

  fn permissioned_burn(ref self: TContractState, from: starknet::ContractAddress, id: u256, amount: u256);
}

#[starknet::interface]
trait KassERC1155ABI<TContractState> {

  // ERC1155 ABI

  fn uri(self: @TContractState, token_id: u256) -> Span<felt252>;

  fn balance_of(self: @TContractState, account: starknet::ContractAddress, id: u256) -> u256;

  fn balance_of_batch(self: @TContractState, accounts: Span<starknet::ContractAddress>, ids: Span<u256>) -> Array<u256>;

  fn is_approved_for_all(self: @TContractState,
    account: starknet::ContractAddress,
    operator: starknet::ContractAddress
  ) -> bool;

  fn set_approval_for_all(ref self: TContractState, operator: starknet::ContractAddress, approved: bool);

  fn safe_transfer_from(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    id: u256,
    amount: u256,
    data: Span<felt252>
  );

  fn safe_batch_transfer_from(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    ids: Span<u256>,
    amounts: Span<u256>,
    data: Span<felt252>
  );

  fn supports_interface(self: @TContractState, interface_id: u32) -> bool;

  // Kass

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, id: u256, amount: u256);

  fn permissioned_burn(ref self: TContractState, from: starknet::ContractAddress, id: u256, amount: u256);
}

#[starknet::contract]
mod KassERC1155 {
  use array::{ SpanSerde, ArrayTrait };
  use rules_erc1155::erc1155::erc1155;
  use rules_erc1155::erc1155::erc1155::ERC1155;
  use rules_erc1155::erc1155::erc1155::ERC1155::{ HelperTrait as ERC1155HelperTrait };
  use rules_erc1155::erc1155::interface::IERC1155;
  use rules_erc1155::introspection::erc165::{ IERC165 as rules_erc1155_IERC165 };

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
  fn constructor(ref self: ContractState, uri_: Span<felt252>) {
    self.initializer(:uri_);
  }

  //
  // ERC1155 ABI impl
  //

  #[external(v0)]
  impl IERC1155Impl of erc1155::ERC1155ABI<ContractState> {

    // IERC1155

    fn uri(self: @ContractState, token_id: u256) -> Span<felt252> {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.uri(:token_id)
    }

    fn balance_of(self: @ContractState, account: starknet::ContractAddress, id: u256) -> u256 {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.balance_of(:account, :id)
    }

    fn balance_of_batch(
      self: @ContractState,
      accounts: Span<starknet::ContractAddress>,
      ids: Span<u256>
    ) -> Array<u256> {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.balance_of_batch(:accounts, :ids)
    }

    fn is_approved_for_all(self: @ContractState,
      account: starknet::ContractAddress,
      operator: starknet::ContractAddress
    ) -> bool {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.is_approved_for_all(:account, :operator)
    }

    fn set_approval_for_all(ref self: ContractState, operator: starknet::ContractAddress, approved: bool) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.set_approval_for_all(:operator, :approved);
    }

    fn safe_transfer_from(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.safe_transfer_from(:from, :to, :id, :amount, :data);
    }

    fn safe_batch_transfer_from(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.safe_batch_transfer_from(:from, :to, :ids, :amounts, :data);
    }

    // IERC165

    fn supports_interface(self: @ContractState, interface_id: u32) -> bool {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.supports_interface(:interface_id)
    }
  }

  //
  // IKassERC1155
  //

  impl IKassERC1155Impl of super::IKassERC1155<ContractState> {
    fn permissioned_mint(ref self: ContractState, to: starknet::ContractAddress, id: u256, amount: u256) {
      // Modifiers
      self._only_deployer();

      // Body
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self._mint(:to, :id, :amount, data: ArrayTrait::new().span());
    }

    fn permissioned_burn(ref self: ContractState, from: starknet::ContractAddress, id: u256, amount: u256) {
      // Modifiers
      self._only_deployer();

      // Body
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self._burn(:from, :id, :amount);
    }
  }

  //
  // Helpers
  //

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn initializer(ref self: ContractState, uri_: Span<felt252>) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.initializer(:uri_);

      let caller = starknet::get_caller_address();
      self._deployer.write(caller);
    }
  }
}
