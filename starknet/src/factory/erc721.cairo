use array::SpanSerde;

#[starknet::interface]
trait IKassERC721<TContractState> {
  fn initialize(ref self: TContractState, name_: felt252, symbol_: felt252, bridge_: starknet::ContractAddress);

  fn permissioned_upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);

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

  // Ownable

  fn owner(self: @TContractState) -> starknet::ContractAddress;

  fn transfer_ownership(ref self: TContractState, new_owner: starknet::ContractAddress);

  fn renounce_ownership(ref self: TContractState);

  // Kass

  fn initialize(ref self: TContractState, name_: felt252, symbol_: felt252);

  fn permissioned_upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);

  fn permissioned_mint(ref self: TContractState, to: starknet::ContractAddress, token_id: u256);

  fn permissioned_burn(ref self: TContractState, token_id: u256);
}

#[starknet::contract]
mod KassERC721 {
  use traits::Into;
  use array::{ SpanSerde, ArrayTrait };
  use zeroable::Zeroable;
  use rules_utils::introspection::interface::{ ISRC5, ISRC5Camel };
  use rules_erc721::erc721::erc721::ERC721;
  use rules_erc721::erc721::erc721::ERC721::InternalTrait as ERC721InternalTrait;
  use rules_erc721::erc721::interface::{ IERC721, IERC721CamelOnly, IERC721Metadata, IERC721MetadataCamelOnly };

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
      assert(self._bridge.read().is_zero(), 'Kass721: Already initialized');

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
  // IKassERC721
  //

  #[external(v0)]
  impl IKassERC721Impl of super::IKassERC721<ContractState> {
    fn initialize(ref self: ContractState, name_: felt252, symbol_: felt252, bridge_: starknet::ContractAddress) {
      // Modifiers
      self._initializer(:bridge_);

      // Body
      self.initializer(:name_, :symbol_);
    }

    fn permissioned_upgrade(ref self: ContractState, new_implementation: starknet::ClassHash) {
      // Modifiers
      self._only_bridge();

      // Body
      self._upgrade(:new_implementation);
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
  // IERC721 impl
  //

  #[external(v0)]
  impl IERC721Impl of IERC721<ContractState> {
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
  }

  //
  // IERC721Camel impl
  //

  #[external(v0)]
  impl IERC721CamelOnlyImpl of IERC721CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: starknet::ContractAddress) -> u256 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.balanceOf(:account)
    }

    fn ownerOf(self: @ContractState, tokenId: u256) -> starknet::ContractAddress {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.ownerOf(:tokenId)
    }

    fn getApproved(self: @ContractState, tokenId: u256) -> starknet::ContractAddress {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.getApproved(:tokenId)
    }

    fn isApprovedForAll(
      self: @ContractState,
      owner: starknet::ContractAddress,
      operator: starknet::ContractAddress
    ) -> bool {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.isApprovedForAll(:owner, :operator)
    }

    fn setApprovalForAll(ref self: ContractState, operator: starknet::ContractAddress, approved: bool) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.setApprovalForAll(:operator, :approved);
    }

    fn transferFrom(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      tokenId: u256
    ) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.transferFrom(:from, :to, :tokenId);
    }

    fn safeTransferFrom(
      ref self: ContractState,
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      tokenId: u256,
      data: Span<felt252>
    ) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.safeTransferFrom(:from, :to, :tokenId, :data);
    }
  }

  //
  // IERC721 Metadata impl
  //

  #[external(v0)]
  impl IERC721MetadataImpl of IERC721Metadata<ContractState> {
    fn name(self: @ContractState) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.name()
    }

    fn symbol(self: @ContractState) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.symbol()
    }

    fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.token_uri(:token_id)
    }
  }

  //
  // IERC721 Metadata impl
  //

  #[external(v0)]
  impl IERC721MetadataCamelOnlyImpl of IERC721MetadataCamelOnly<ContractState> {
    fn tokenUri(self: @ContractState, tokenId: u256) -> felt252 {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.tokenUri(:tokenId)
    }
  }

  //
  // ISRC5 impl
  //

  #[external(v0)]
  impl ISRC5Impl of ISRC5<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.supports_interface(:interface_id)
    }
  }

  //
  // ISRC5 Camel impl
  //

  #[external(v0)]
  impl ISRC5CamelImpl of ISRC5Camel<ContractState> {
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
      let erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.supportsInterface(:interfaceId)
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
    fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      // ERC721 init
      erc721_self.initializer(:name_, :symbol_);

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
