use array::SpanSerde;

#[starknet::interface]
trait IKassToken<TContractState> {
  fn initialize(ref self: TContractState, implementation: starknet::ClassHash, calldata: Span<felt252>);
}

#[starknet::interface]
trait KassTokenABI<TContractState> {
  fn initialize(ref self: TContractState, implementation: starknet::ClassHash, calldata: Span<felt252>);
}

mod selectors {
  const initialize: felt252 = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;
}

#[starknet::contract]
mod KassToken {
  use traits::Into;
  use array::{ ArrayTrait, SpanSerde };
  use rules_utils::utils::array::ArrayTraitExt;

  // locals
  use kass::factory::common;
  use kass::factory::common::IKassToken;
  use super::selectors;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _deployer: starknet::ContractAddress,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState, deployer_: starknet::ContractAddress) {
    // since address computation is not based on the addr of the caller, we need to specify it in the calldata
    // to enforce this behaviour.
    self.initializer(:deployer_);
  }

  //
  // IKassToken impl
  //

  #[external(v0)]
  impl IKassTokenImpl of common::IKassToken<ContractState> {
    fn initialize(ref self: ContractState, implementation: starknet::ClassHash, calldata: Span<felt252>) {
      // set new impl
      starknet::replace_class_syscall(implementation);

      // initialize new impl
      let singleton_bridge = array![self._deployer.read().into()];

      starknet::library_call_syscall(
        class_hash: implementation,
        function_selector: selectors::initialize,
        calldata: calldata.snapshot.concat(@singleton_bridge).span()
      ).unwrap_syscall();
    }
  }

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(ref self: ContractState, deployer_: starknet::ContractAddress) {
      self._deployer.write(deployer_);
    }
  }
}
