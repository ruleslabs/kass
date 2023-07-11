use core::traits::TryInto;
#[starknet::contract]
mod KassTokenDeployer {
  use traits::{ Into, TryInto };
  use array::{ ArrayTrait, SpanTrait, SpanSerde };
  use zeroable::Zeroable;
  use option::OptionTrait;
  use rules_utils::utils::into::BoolIntoU8;
  use rules_utils::utils::hash::EthAddressLegacyHash;
  use rules_erc721::erc721;
  use rules_erc1155::erc1155;

  // locals
  use kass::bridge::interface::IKassTokenDeployer;

  // Dispatchers
  use kass::factory::common::{ KassTokenABIDispatcher, KassTokenABIDispatcherTrait };

  const SUPPORTS_INTERFACE_SELECTOR: felt252 = 0xfe80f537b66d12a00b6d3c072b44afbb716e78dde5c3f0ef116ee93d3e3283;

  const CONTRACT_ADDRESS_PREFIX: felt252 = 0x19c4f5a32bf8efb8ff328e8933002412ad1a38b70e8e8d672289996cc025fcd;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    // Address of the Kass token implementation
    _token_implementation: starknet::ClassHash,

    // Address of the Kass ERC721 implementation
    _erc721_implementation: starknet::ClassHash,

    // Address of the Kass ERC1155 implementation
    _erc1155_implementation: starknet::ClassHash,

    // l1 token address -> l2 kass token address
    _kass_token_addresses: LegacyMap<starknet::EthAddress, starknet::ContractAddress>,
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
    fn token_implementation(self: @ContractState) -> starknet::ClassHash {
      self._token_implementation.read()
    }

    fn erc721_implementation(self: @ContractState) -> starknet::ClassHash {
      self._erc721_implementation.read()
    }

    fn erc1155_implementation(self: @ContractState) -> starknet::ClassHash {
      self._erc1155_implementation.read()
    }

    fn l2_kass_token_address(
      self: @ContractState,
      l1_token_address: starknet::EthAddress
    ) -> starknet::ContractAddress {
      self._kass_token_addresses.read(l1_token_address)
    }

    fn compute_l2_kass_token_address(
      self: @ContractState,
      l1_token_address: starknet::EthAddress
    ) -> starknet::ContractAddress {
      // deployer (always zero)
      let deployer_address = 0;

      // salt
      let salt: felt252 = l1_token_address.into();

      // class hash
      let class_hash: felt252 = self.token_implementation().into();

      // calldata
      let caller = starknet::get_caller_address();

      let mut calldata_hash = pedersen(0, caller.into());
      calldata_hash = pedersen(calldata_hash, 1);

      // compute address
      let mut address = CONTRACT_ADDRESS_PREFIX;
      address = pedersen(address, 0);
      address = pedersen(address, salt);
      address = pedersen(address, class_hash);
      address = pedersen(address, calldata_hash);

      pedersen(address, 5).try_into().unwrap()
    }

    fn set_deployer_class_hashes(
      ref self: ContractState,
      token_implementation_: starknet::ClassHash,
      erc721_implementation_: starknet::ClassHash,
      erc1155_implementation_: starknet::ClassHash
    ) {
      // assert implementations are valid
      assert(token_implementation_.is_non_zero(), 'Invalid token implementation');
      assert(
        self._implementation_supports_interface(
          implementation: erc721_implementation_,
          interface_id: erc721::interface::IERC721_ID
        ),
        'Invalid ERC721 implementation'
      );
      assert(
        self._implementation_supports_interface(
          implementation: erc1155_implementation_,
          interface_id: erc1155::interface::IERC1155_ID
        ),
        'Invalid ERC1155 implementation'
      );

      self._token_implementation.write(token_implementation_);
      self._erc721_implementation.write(erc721_implementation_);
      self._erc1155_implementation.write(erc1155_implementation_);
    }
  }

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn _deploy_kass_erc721(
      ref self: ContractState,
      l1_token_address: starknet::EthAddress,
      calldata: Span<felt252>
    ) -> starknet::ContractAddress {
      self._deploy_kass_token(implementation: self.erc721_implementation(), :l1_token_address, :calldata)
    }

    fn _deploy_kass_erc1155(
      ref self: ContractState,
      l1_token_address: starknet::EthAddress,
      calldata: Span<felt252>
    ) -> starknet::ContractAddress {
      self._deploy_kass_token(implementation: self.erc1155_implementation(), :l1_token_address, :calldata)
    }

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

    fn _deploy_kass_token(
      ref self: ContractState,
      implementation: starknet::ClassHash,
      l1_token_address: starknet::EthAddress,
      calldata: Span<felt252>
    ) -> starknet::ContractAddress {
      let mut singleton_caller = ArrayTrait::new();

      let caller = starknet::get_caller_address();
      singleton_caller.append(caller.into());

      let (kass_contract_address, _) = starknet::syscalls::deploy_syscall(
        class_hash: self.token_implementation(),
        contract_address_salt: l1_token_address.into(),
        calldata: singleton_caller.span(),
        deploy_from_zero: true
      ).unwrap_syscall();

      // upgrade to the given implementation
      let token_contract = KassTokenABIDispatcher { contract_address: kass_contract_address };

      token_contract.initialize(:implementation, :calldata);

      // save token address
      self._kass_token_addresses.write(l1_token_address, kass_contract_address);

      kass_contract_address
    }
  }
}
