#[starknet::contract]
mod KassTokenDeployer {
  use traits::Into;
  use array::{ ArrayTrait, SpanTrait, SpanSerde };
  use rules_utils::utils::into::BoolIntoU8;
  use rules_erc721::erc721;
  use rules_erc1155::erc1155;

  // locals
  use kass::bridge::interface::IKassTokenDeployer;

  const SUPPORTS_INTERFACE_SELECTOR: felt252 = 0xfe80f537b66d12a00b6d3c072b44afbb716e78dde5c3f0ef116ee93d3e3283;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    // Address of the Kass ERC721 implementation
    _erc721_implementation_address: starknet::ClassHash,

    // Address of the Kass ERC1155 implementation
    _erc1155_implementation_address: starknet::ClassHash,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState) { }

  //
  // ITokenDeployer impl
  //

  #[external(v0)]
  impl IKassTokenDeployerImpl of IKassTokenDeployer<ContractState> {
    fn set_deployer_class_hashes(
      ref self: ContractState,
      erc721_implementation_address_: starknet::ClassHash,
      erc1155_implementation_address_: starknet::ClassHash
    ) {
      // assert implementations are valid
      assert(
        self._implementation_supports_interface(
          implementation: erc721_implementation_address_,
          interface_id: erc721::interface::IERC721_ID
        ),
        'Invalid ERC721 implementation'
      );
      assert(
        self._implementation_supports_interface(
          implementation: erc1155_implementation_address_,
          interface_id: erc1155::interface::IERC1155_ID
        ),
        'Invalid ERC1155 implementation'
      );

      self._erc721_implementation_address.write(erc721_implementation_address_); // TODO: declare class hash
      self._erc1155_implementation_address.write(erc1155_implementation_address_); // TODO: declare class hash
    }

    fn deploy_kass_erc721(ref self: ContractState, salt: felt252, calldata: Span<felt252>) -> starknet::ContractAddress {
      let (contractAddress, _) = starknet::syscalls::deploy_syscall(
        class_hash: self._erc721_implementation_address.read(),
        contract_address_salt: salt,
        :calldata,
        deploy_from_zero: true
      ).unwrap_syscall();

      return contractAddress;
    }

    fn deploy_kass_erc1155(ref self: ContractState, salt: felt252, calldata: Span<felt252>) -> starknet::ContractAddress {
      let (contractAddress, _) = starknet::syscalls::deploy_syscall(
        class_hash: self._erc1155_implementation_address.read(),
        contract_address_salt: salt,
        :calldata,
        deploy_from_zero: true
      ).unwrap_syscall();

      return contractAddress;
    }
  }

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn _implementation_supports_interface(
      ref self: ContractState,
      implementation: starknet::ClassHash,
      interface_id: u32
    ) -> bool {
      let mut calldata = ArrayTrait::new();

      calldata.append(interface_id.into());

      let ret_data = starknet::library_call_syscall(
        class_hash: implementation,
        function_selector: SUPPORTS_INTERFACE_SELECTOR,
        calldata: calldata.span()
      ).unwrap_syscall();

      (ret_data.len() == 1) & (*ret_data.at(0) == Into::<bool, u8>::into(true).into())
    }
  }
}