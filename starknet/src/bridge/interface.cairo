use array::SpanSerde;

#[starknet::interface]
trait IKassBridge<TContractState> {
  fn get_version(self: @TContractState) -> felt252;

  fn get_identity(self: @TContractState) -> felt252;

  fn request_ownership(
    ref self: TContractState,
    l2_token_address: starknet::ContractAddress,
    l1_owner: starknet::EthAddress
  );

  fn deposit_721(
    ref self: TContractState,
    native_token_address: felt252,
    recipient: starknet::EthAddress,
    token_id: u256,
    request_wrapper: bool
  );

  fn deposit_1155(
    ref self: TContractState,
    native_token_address: felt252,
    recipient: starknet::EthAddress,
    token_id: u256,
    amount: u256,
    request_wrapper: bool
  );
}

#[starknet::interface]
trait IKassBridgeHandlers<TContractState> {
  fn claim_ownership(
    ref self: TContractState,
    from_address: starknet::EthAddress,
    l1_token_address: starknet::EthAddress,
    owner: starknet::ContractAddress
  );

  fn withdraw_721(
    ref self: TContractState,
    from_address: starknet::EthAddress,
    native_token_address: felt252,
    recipient: starknet::ContractAddress,
    token_id: u256,
    amount: u256,
    calldata: Span<felt252>
  );

  fn withdraw_1155(
    ref self: TContractState,
    from_address: starknet::EthAddress,
    native_token_address: felt252,
    recipient: starknet::ContractAddress,
    token_id: u256,
    amount: u256,
    calldata: Span<felt252>
  );
}

#[starknet::interface]
trait IKassTokenDeployer<TContractState> {
  fn token_implementation(self: @TContractState) -> starknet::ClassHash;

  fn erc721_implementation(self: @TContractState) -> starknet::ClassHash;

  fn erc1155_implementation(self: @TContractState) -> starknet::ClassHash;

  fn l2_kass_token_address(
    self: @TContractState,
    l1_token_address: starknet::EthAddress
  ) -> starknet::ContractAddress;

  fn compute_l2_kass_token_address(
    self: @TContractState,
    l1_token_address: starknet::EthAddress
  ) -> starknet::ContractAddress;

  fn set_deployer_class_hashes(
    ref self: TContractState,
    token_implementation_: starknet::ClassHash,
    erc721_implementation_: starknet::ClassHash,
    erc1155_implementation_: starknet::ClassHash
  );
}

#[starknet::interface]
trait IKassMessaging<TContractState> {
  fn l1_kass_address(self: @TContractState) -> starknet::EthAddress;

  fn set_l1_kass_address(ref self: TContractState, l1_kass_address_: starknet::EthAddress);
}
