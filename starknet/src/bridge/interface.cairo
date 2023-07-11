use array::SpanSerde;

#[starknet::interface]
trait IKassBridge<TContractState> {
  fn get_version(self: @TContractState) -> felt252;

  fn get_identity(self: @TContractState) -> felt252;

  fn request_l1_ownership(ref self: TContractState);

  fn deposit_721(ref self: TContractState, token_address: felt252, l1_recipient: starknet::EthAddress, token_id: u256);

  fn deposit_1155(
    ref self: TContractState,
    token_address: felt252,
    l1_recipient: starknet::EthAddress,
    token_id: u256,
    amount: u256
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
