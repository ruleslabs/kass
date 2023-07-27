#[starknet::interface]
trait IERC721Mock<TContractState> {
  fn mint(ref self: TContractState, token_id: u256);
}

#[starknet::contract]
mod ERC721Mock {
  use rules_utils::introspection::interface::ISRC5;

  //locals
  use rules_erc721::erc721::interface::{ IERC721, IERC721Metadata };
  use rules_erc721::erc721::erc721::ERC721;
  use rules_erc721::erc721::erc721::ERC721::InternalTrait as ERC721InternalTrait;

  use super::super::ownable::{ Ownable, IOwnable };
  use super::super::ownable::Ownable::InternalTrait as OwnableInternalTrait;

  //
  // Storage
  //

  #[storage]
  struct Storage {}

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState, name_: felt252, symbol_: felt252) {
    let mut erc721_self = ERC721::unsafe_new_contract_state();
    let mut ownable_self = Ownable::unsafe_new_contract_state();

    erc721_self.initializer(:name_, :symbol_);
    ownable_self.initializer();
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

    fn set_approval_for_all(ref self: ContractState, operator: starknet::ContractAddress, approved: bool) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      erc721_self.set_approval_for_all(:operator, :approved);
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
  // Ownable impl
  //

  #[external(v0)]
  impl IOwnableImpl of IOwnable<ContractState> {
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
  // IERC721Mock impl
  //

  #[external(v0)]
  impl IERC721MockImpl of super::IERC721Mock<ContractState> {
    fn mint(ref self: ContractState, token_id: u256) {
      let mut erc721_self = ERC721::unsafe_new_contract_state();

      let caller = starknet::get_caller_address();

      erc721_self._mint(to: caller, :token_id);
    }
  }
}
