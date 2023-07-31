use array::SpanSerde;

#[starknet::interface]
trait IKassERC1155<TContractState> {
  fn initialize(ref self: TContractState, uri_: Span<felt252>, bridge_: starknet::ContractAddress);

  fn permissioned_upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);

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

  // Ownable

  fn owner(self: @TContractState) -> starknet::ContractAddress;

  fn transfer_ownership(ref self: TContractState, new_owner: starknet::ContractAddress);

  fn renounce_ownership(ref self: TContractState);

  // Upgradeable

  fn upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);

  // Kass

  fn initialize(ref self: TContractState, uri_: Span<felt252>, bridge_: starknet::ContractAddress);

  fn permissioned_upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, id: u256, amount: u256);

  fn permissioned_burn(ref self: TContractState, from: starknet::ContractAddress, id: u256, amount: u256);
}

#[starknet::contract]
mod KassERC1155 {
  use array::{ SpanSerde, ArrayTrait };
  use zeroable::Zeroable;
  use rules_utils::introspection::interface::{ ISRC5, ISRC5Camel };
  use rules_erc1155::erc1155::erc1155::ERC1155;
  use rules_erc1155::erc1155::erc1155::ERC1155::InternalTrait as ERC1155InternalTrait;
  use rules_erc1155::erc1155::interface::{ IERC1155, IERC1155CamelOnly, IERC1155Metadata };

  // locals
  use kass::access::ownable;
  use kass::access::ownable::{ Ownable, IOwnable };
  use kass::access::ownable::Ownable::{ InternalTrait as OwnableInternalTrait, ModifierTrait as OwnableModifierTrait };

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
      assert(self._bridge.read().is_zero(), 'Kass1155: Already initialized');

      self._bridge.write(bridge_);
    }

    fn _only_bridge(self: @ContractState) {
      let bridge_ = self._bridge.read();
      let caller = starknet::get_caller_address();

      assert(caller.is_non_zero(), 'Caller is the zero address');
      assert(caller == bridge_, 'Caller is not the bridge');
    }

    fn _only_owner(self: @ContractState) {
      let ownable_self = Ownable::unsafe_new_contract_state();

      ownable_self.assert_only_owner();
    }
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState) { }

  //
  // Upgrade impl
  //

  #[external(v0)]
  #[generate_trait]
  impl UpgradeImpl of UpgradeTrait {
    fn upgrade(ref self: ContractState, new_implementation: starknet::ClassHash) {
      // Modifiers
      self._only_owner();

      // Body
      self._upgrade(:new_implementation);
    }
  }

  //
  // IKassERC1155
  //

  #[external(v0)]
  impl IKassERC1155Impl of super::IKassERC1155<ContractState> {
    fn initialize(ref self: ContractState, uri_: Span<felt252>, bridge_: starknet::ContractAddress) {
      // Modifiers
      self._initializer(:bridge_);

      // Body
      self.initializer(:uri_);
    }

    fn permissioned_upgrade(ref self: ContractState, new_implementation: starknet::ClassHash) {
      // Modifiers
      self._only_bridge();

      // Body
      self._upgrade(:new_implementation);
    }

    fn permissioned_mint(ref self: ContractState, to: starknet::ContractAddress, id: u256, amount: u256) {
      // Modifiers
      self._only_bridge();

      // Body
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self._mint(:to, :id, :amount, data: array![].span());
    }

    fn permissioned_burn(ref self: ContractState, from: starknet::ContractAddress, id: u256, amount: u256) {
      // Modifiers
      self._only_bridge();

      // Body
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self._burn(:from, :id, :amount);
    }
  }

  //
  // ERC1155 ABI impl
  //

  #[external(v0)]
  impl IERC1155Impl of IERC1155<ContractState> {
    fn balance_of(self: @ContractState, account: starknet::ContractAddress, id: u256) -> u256 {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.balance_of(:account, :id)
    }

    fn balance_of_batch(
      self: @ContractState,
      accounts: Span<starknet::ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
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
  }

  //
  // IERC1155 Camel impl
  //

  #[external(v0)]
  impl IERC1155CamelOnlyImpl of IERC1155CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: starknet::ContractAddress, id: u256) -> u256 {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.balanceOf(:account, :id)
    }

    fn balanceOfBatch(
      self: @ContractState,
      accounts: Span<starknet::ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.balanceOfBatch(:accounts, :ids)
    }

    fn isApprovedForAll(self: @ContractState,
      account: starknet::ContractAddress,
      operator: starknet::ContractAddress
    ) -> bool {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.isApprovedForAll(:account, :operator)
    }

    fn setApprovalForAll(ref self: ContractState, operator: starknet::ContractAddress, approved: bool) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.setApprovalForAll(:operator, :approved);
    }

    fn safeTransferFrom(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.safeTransferFrom(:from, :to, :id, :amount, :data);
    }

    fn safeBatchTransferFrom(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.safeBatchTransferFrom(:from, :to, :ids, :amounts, :data);
    }
  }

  //
  // IERC1155 Metadata impl
  //

  #[external(v0)]
  impl IERC1155MetadataImpl of IERC1155Metadata<ContractState> {
    fn uri(self: @ContractState, token_id: u256) -> Span<felt252> {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.uri(:token_id)
    }
  }

  //
  // ISRC5 impl
  //

  #[external(v0)]
  impl ISRC5Impl of ISRC5<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.supports_interface(:interface_id)
    }
  }

  //
  // ISRC5 Camel impl
  //

  #[external(v0)]
  impl ISRC5CamelImpl of ISRC5Camel<ContractState> {
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
      let erc1155_self = ERC1155::unsafe_new_contract_state();

      erc1155_self.supportsInterface(:interfaceId)
    }
  }

  //
  // Ownable impl
  //

  #[external(v0)]
  impl IOwnableImpl of ownable::IOwnable<ContractState> {
    fn owner(self: @ContractState) -> starknet::ContractAddress {
      let ownable_self = Ownable::unsafe_new_contract_state();

      ownable_self.owner()
    }

    fn transfer_ownership(ref self: ContractState, new_owner: starknet::ContractAddress) {
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      ownable_self.transfer_ownership(:new_owner);
    }

    fn renounce_ownership(ref self: ContractState) {
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      ownable_self.renounce_ownership();
    }
  }

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(ref self: ContractState, uri_: Span<felt252>) {
      let mut erc1155_self = ERC1155::unsafe_new_contract_state();
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      // ERC1155 init
      erc1155_self.initializer(:uri_);

      // bridge and owner init
      let caller = starknet::get_caller_address();

      self._bridge.write(caller);
      ownable_self._transfer_ownership(new_owner: caller);
    }

    fn _upgrade(ref self: ContractState, new_implementation: starknet::ClassHash) {
      starknet::replace_class_syscall(new_implementation);
    }
  }
}
