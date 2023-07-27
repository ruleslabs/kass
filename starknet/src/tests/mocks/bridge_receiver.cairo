#[starknet::contract]
mod BridgeReceiverMock {
  use rules_erc1155::erc1155::interface::{ IERC1155Receiver, IERC1155ReceiverCamel, ON_ERC1155_RECEIVED_SELECTOR };

  //
  // Storage
  //

  #[storage]
  struct Storage { }

  //
  // IERC1155Receiver impl
  //

  #[external(v0)]
  impl IERC1155ReceiverImpl of IERC1155Receiver<ContractState> {
    fn on_erc1155_received(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      id: u256,
      value: u256,
      data: Span<felt252>
    ) -> felt252 {
      let contract_address = starknet::get_contract_address();

      // validate transfer only if it's executed in the context of a deposit
      if (contract_address == operator) {
        ON_ERC1155_RECEIVED_SELECTOR
      } else {
        0
      }
    }

    fn on_erc1155_batch_received(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      ids: Span<u256>,
      values: Span<u256>,
      data: Span<felt252>
    ) -> felt252 {
      // does not support batch transfers
      0
    }
  }

  //
  // IERC1155Receiver Camel impl
  //

  #[external(v0)]
  impl IERC1155ReceiverCamelImpl of IERC1155ReceiverCamel<ContractState> {
    fn onERC1155Received(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      id: u256,
      value: u256,
      data: Span<felt252>
    ) -> felt252 {
      let contract_address = starknet::get_contract_address();

      // validate transfer only if it's executed in the context of a deposit
      if (contract_address == operator) {
        ON_ERC1155_RECEIVED_SELECTOR
      } else {
        0
      }
    }

    fn onERC1155BatchReceived(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      ids: Span<u256>,
      values: Span<u256>,
      data: Span<felt252>
    ) -> felt252 {
      // does not support batch transfers
      0
    }
  }
}
