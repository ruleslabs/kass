#[starknet::interface]
trait KassABI<TContractState> {

}

#[starknet::contract]
mod Kass {
  use array::ArrayTrait;
  use traits::{ Into, TryInto };
  use option::OptionTrait;
  use zeroable::Zeroable;
  use starknet::{ EthAddressZeroable, Felt252TryIntoEthAddress, EthAddressIntoFelt252, ContractAddressIntoFelt252 };
  use rules_erc1155::erc1155;

  // locals
  use kass::bridge;
  use kass::bridge::interface::{ IKassMessaging, IKassTokenDeployer };
  use kass::bridge::token_standard::{ TokenStandard, ContractAddressInterfacesTrait };
  use kass::bridge::token_deployer::KassTokenDeployer;

  use kass::bridge::messaging::KassMessaging;
  use kass::bridge::messaging::KassMessaging::{ HelperTrait as KassMessagingHelperTrait };

  use kass::access::ownable;
  use kass::access::ownable::Ownable;
  use kass::access::ownable::Ownable::{ HelperTrait as OwnableHelperTrait, ModifierTrait as OwnableModifierTrait };

  // Dispatchers
  use kass::access::ownable::{ IOwnableDispatcher, IOwnableDispatcherTrait };
  use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };
  use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };

  const CONTRACT_IDENTITY: felt252 = 'Kass';
  const CONTRACT_VERSION: felt252 = '1.0.0';

  //
  // Storage
  //

  #[storage]
  struct Storage { }

  //
  // Modifiers
  //

  #[generate_trait]
  impl ModifierImpl of ModifierTrait {
    fn _l1_handler(self: @ContractState, from_address: starknet::EthAddress) {
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      assert(from_address == kass_messaging_self.l1_kass_address(), 'EXPECTED_FROM_L1_KASS_ONLY');
    }

    fn _only_owner(self: @ContractState) {
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      ownable_self.assert_only_owner();
    }
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(
      ref self: ContractState,
      owner_: starknet::ContractAddress,
      l1_kass_address_: starknet::EthAddress,
      token_implementation_address_: starknet::ClassHash,
      erc721_implementation_address_: starknet::ClassHash,
      erc1155_implementation_address_: starknet::ClassHash
    ) {
      self.initializer(
        :owner_,
        :l1_kass_address_,
        :token_implementation_address_,
        :erc721_implementation_address_,
        :erc1155_implementation_address_
      );
    }

  //
  // IKassBridge impl
  //

  #[external(v0)]
  impl IKassBridgeImpl of bridge::interface::IKassBridge<ContractState> {
    fn get_version(self: @ContractState) -> felt252 {
      CONTRACT_VERSION
    }

    fn get_identity(self: @ContractState) -> felt252 {
      CONTRACT_IDENTITY
    }

    fn request_l1_ownership(ref self: ContractState) {

    }

    fn deposit_721(
      ref self: ContractState,
      token_address: felt252,
      l1_recipient: starknet::EthAddress,
      token_id: u256
    ) {
      self._deposit(:token_address, :l1_recipient, :token_id, amount: u256 { low: 1, high: 0 });
    }

    fn deposit_1155(
      ref self: ContractState,
      token_address: felt252,
      l1_recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256
    ) {
      self._deposit(:token_address, :l1_recipient, :token_id, :amount);
    }
  }

  //
  // IKassMessaging impl
  //

  impl IKassMessagingImpl of bridge::interface::IKassMessaging<ContractState> {
    fn l1_kass_address(self: @ContractState) -> starknet::EthAddress {
      let kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      kass_messaging_self.l1_kass_address()
    }

    fn set_l1_kass_address(ref self: ContractState, l1_kass_address_: starknet::EthAddress) {
      // Modifiers
      self._only_owner();

      // Body
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      kass_messaging_self.set_l1_kass_address(:l1_kass_address_);
    }
  }

  //
  // Handlers
  //

  // Wrapper creation

  #[generate_trait]
  #[l1_handler]
  impl HandlerImpl of HandlerTrait {
    fn createL2Wrapper721(
      ref self: ContractState,
      from_address: felt252,
      l1_token_address: starknet::EthAddress,
      data: Array<felt252>
    ) {
      // Modifiers
      self._l1_handler(from_address.try_into().unwrap());

      // Body
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      // deploy Kass ERC 721
      kass_token_deployer_self.deploy_kass_erc721(salt: l1_token_address.into(), calldata: data.span());
    }

    fn createL2Wrapper1155(
      ref self: ContractState,
      from_address: felt252,
      l1_token_address: starknet::EthAddress,
      data: Array<felt252>
    ) {
      // Modifiers
      self._l1_handler(from_address.try_into().unwrap());

      // Body
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      // deploy Kass ERC 1155
      kass_token_deployer_self.deploy_kass_erc1155(salt: l1_token_address.into(), calldata: data.span());
    }

    // Ownership claim

    fn claimL2Ownership(
      ref self: ContractState,
      from_address: felt252,
      l1_token_address: starknet::EthAddress,
      l2Owner: starknet::ContractAddress
    ) {
      // Modifiers
      self._l1_handler(from_address.try_into().unwrap());

      // get L2 token wrapper
      let l2TokenAddress = starknet::contract_address_const::<0>(); // TODO: compute contract address

      // transfer ownership
      IOwnableDispatcher { contract_address: l2TokenAddress }.transfer_ownership(l2Owner);

      // emit event
    }

    fn withdraw721(
      ref self: ContractState,
      from_address: felt252,
      token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256
    ) {
      // Modifiers
      self._l1_handler(from_address.try_into().unwrap());

      // body
      self._withdraw(:token_address, :recipient, :token_id, amount: u256 { low: 1, high: 0 });
    }

    fn withdraw1155(
      ref self: ContractState,
      from_address: felt252,
      token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256
    ) {
      // modifiers
      self._l1_handler(from_address.try_into().unwrap());

      // body
      self._withdraw(:token_address, :recipient, :token_id, :amount);
    }
  }

  // OWNERSHIP REQUEST

  fn requestL1Ownership(token_address: starknet::ContractAddress, l1_owner: starknet::EthAddress) {
    let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

    // assert L2 token owner is sender
    let caller = starknet::get_caller_address();
    assert(
      IOwnableDispatcher { contract_address: token_address }.owner() == caller,
      'Caller is not the owner'
    );

    // send L2 wrapper request message
    kass_messaging_self._send_l1_ownership_request_message(:token_address, :l1_owner);

    // emit event
  }

  //
  // IERC1155Receiver impl
  //

  #[external(v0)]
  impl IERC1155ReceiverImpl of erc1155::interface::IERC1155Receiver<ContractState> {
    fn on_erc1155_received(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      id: u256,
      value: u256,
      data: Span<felt252>
    ) -> u32 {
      let contractAddress = starknet::get_contract_address();

      // validate transfer only if it's executed in the context of a deposit
      if (contractAddress == operator) {
        return erc1155::interface::ON_ERC1155_RECEIVED_SELECTOR;
      }

      0_u32
    }

    fn on_erc1155_batch_received(
      ref self: ContractState,
      operator: starknet::ContractAddress,
      from: starknet::ContractAddress,
      ids: Span<u256>,
      values: Span<u256>,
      data: Span<felt252>
    ) -> u32 {
      // does not support batch transfers
      0_32
    }
  }

  //
  // Helpers
  //

  #[generate_trait]
  impl HelperImpl of HelperTrait {
    fn initializer(
      ref self: ContractState,
      owner_: starknet::ContractAddress,
      l1_kass_address_: starknet::EthAddress,
      token_implementation_address_: starknet::ClassHash,
      erc721_implementation_address_: starknet::ClassHash,
      erc1155_implementation_address_: starknet::ClassHash
    ) {
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      kass_messaging_self.set_l1_kass_address(:l1_kass_address_);

      kass_token_deployer_self.set_deployer_class_hashes(
        :token_implementation_address_,
        :erc721_implementation_address_,
        :erc1155_implementation_address_
      );

      ownable_self._transfer_ownership(new_owner: owner_);
    }


    // Deposit

    fn _deposit(
      ref self: ContractState,
      token_address: felt252,
      l1_recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256
    ) {
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      // TODO: get real data
      let is_native = false;
      let l2TokenAddress = starknet::contract_address_const::<0x42>();

      // burn or tranfer tokens
      self._lockTokens(token_address: l2TokenAddress, :token_id, :amount, :is_native);

      kass_messaging_self._send_token_deposit_message(:token_address, recipient: l1_recipient, :token_id, :amount);
    }

    // Withdraw

    fn _withdraw(
      ref self: ContractState,
      token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
    ) {
      // TODO: get real data
      let is_native = false;
      let l2TokenAddress = starknet::contract_address_const::<0x42>();

      self._unlockTokens(token_address: l2TokenAddress, :recipient, :token_id, :amount, :is_native);
    }

    // Tokens

    fn _lockTokens(
      ref self: ContractState,
      token_address: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
      is_native: bool
    ) {
      let caller = starknet::get_caller_address();
      let contractAddress = starknet::get_contract_address();

      if (token_address.isERC721()) {
        let KassERC721 = KassERC721ABIDispatcher { contract_address: token_address };

        if (is_native) {
          KassERC721.transfer_from(from: caller, to: contractAddress, :token_id);
        } else {
          // check if caller is owner before burning
          assert(KassERC721.owner_of(:token_id) == caller, 'You do not own this token');

          KassERC721.permissioned_burn(:token_id);
        }

        return ();
      } else if (token_address.isERC1155()) {
        assert(amount > u256 {low: 0, high: 0 }, 'Cannot deposit null amount');

        let KassERC1155 = KassERC1155ABIDispatcher { contract_address: token_address };

        if (is_native) {
          KassERC1155.safe_transfer_from(
            from: caller,
            to: contractAddress,
            id: token_id,
            :amount,
            data: ArrayTrait::new().span()
          );
        } else {
          KassERC1155.permissioned_burn(from: caller, id: token_id, :amount);
        }

        return ();
      } else {
        panic_with_felt252('Kass: Unkown token standard');
      }
    }

    fn _unlockTokens(
      ref self: ContractState,
      token_address: starknet::ContractAddress,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
      is_native: bool
    ) {
      let contractAddress = starknet::get_contract_address();

      if (token_address.isERC721()) {
        let KassERC721 = KassERC721ABIDispatcher { contract_address: token_address };

        if (is_native) {
          KassERC721.transfer_from(from: contractAddress, to: recipient, :token_id);
        } else {
          KassERC721.permissioned_mint(to: recipient, :token_id);
        }

        return ();
      } else if (token_address.isERC1155()) {
        assert(amount > u256 {low: 0, high: 0 }, 'Cannot withdraw null amount');

        let KassERC1155 = KassERC1155ABIDispatcher { contract_address: token_address };

        if (is_native) {
          KassERC1155.safe_transfer_from(
            from: contractAddress,
            to: recipient,
            id: token_id,
            :amount,
            data: ArrayTrait::new().span()
          );
        } else {
          KassERC1155.permissioned_mint(to: recipient, id: token_id, :amount);
        }

        return ();
      } else {
        panic_with_felt252('Kass: Unkown token standard');
      }
    }
  }
}
