use core::array::SpanTrait;
#[starknet::interface]
trait KassBridgeABI<TContractState> {

}

#[starknet::contract]
mod KassBridge {
  use array::{ ArrayTrait, SpanTrait };
  use traits::{ Into, TryInto };
  use option::OptionTrait;
  use zeroable::Zeroable;
  use starknet::{ EthAddressZeroable, Felt252TryIntoEthAddress, EthAddressIntoFelt252, ContractAddressIntoFelt252 };

  use rules_erc1155::erc1155::interface::{ IERC1155Receiver, IERC1155ReceiverCamel, ON_ERC1155_RECEIVED_SELECTOR };

  use rules_utils::utils::contract_address::ContractAddressTraitExt;

  // Dispatchers
  use rules_erc721::erc721::dual_erc721::{ DualCaseERC721, DualCaseERC721Trait };
  use rules_erc1155::erc1155::dual_erc1155::{ DualCaseERC1155, DualCaseERC1155Trait };

  // locals
  use kass::bridge;
  use kass::bridge::interface::{ IKassMessaging, IKassTokenDeployer };

  use kass::bridge::token_standard::{ TokenStandard, ContractAddressInterfacesTrait };
  use kass::bridge::token_deployer::KassTokenDeployer;
  use kass::bridge::token_deployer::KassTokenDeployer::{ InternalTrait as KassTokenDeployerInternalTrait };

  use kass::bridge::messaging::KassMessaging;
  use kass::bridge::messaging::KassMessaging::{ InternalTrait as KassMessagingInternalTrait };

  use kass::access::ownable;
  use kass::access::ownable::Ownable;
  use kass::access::ownable::Ownable::{ InternalTrait as OwnableInternalTrait, ModifierTrait as OwnableModifierTrait };

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
  // Events
  //

  #[event]
  #[derive(Drop, starknet::Event)]
  enum Event {
    WrapperCreation: WrapperCreation,
    WrapperRequest: WrapperRequest,
    OwnershipClaim: OwnershipClaim,
    OwnershipRequest: OwnershipRequest,
    Deposit: Deposit,
    Withdraw: Withdraw,
  }

  // Wrapper

  #[derive(Drop, starknet::Event)]
  struct WrapperCreation {
    l1_token_address: starknet::EthAddress,
    l2_token_address: starknet::ContractAddress,
  }


  #[derive(Drop, starknet::Event)]
  struct WrapperRequest {
    l2_token_address: starknet::ContractAddress,
  }

  // Ownership

  #[derive(Drop, starknet::Event)]
  struct OwnershipClaim {
    l1_token_address: starknet::EthAddress,
    l2_token_address: starknet::ContractAddress,
    l2_owner: starknet::ContractAddress,
  }

  #[derive(Drop, starknet::Event)]
  struct OwnershipRequest {
    l2_token_address: starknet::ContractAddress,
    l1_owner: starknet::EthAddress,
  }

  // Deposit

  #[derive(Drop, starknet::Event)]
  struct Deposit {
    native_token_address: felt252,
    sender: starknet::ContractAddress,
    recipient: starknet::EthAddress,
    token_id: u256,
    amount: u256,
  }

  #[derive(Drop, starknet::Event)]
  struct Withdraw {
    native_token_address: felt252,
    recipient: starknet::ContractAddress,
    token_id: u256,
    amount: u256,
  }

  // Withdraw

  //
  // Modifiers
  //

  #[generate_trait]
  impl ModifierImpl of ModifierTrait {
    fn _l1_handler(self: @ContractState, from_address: starknet::EthAddress) {
      let kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      assert(from_address == kass_messaging_self.l1_kass_address(), 'EXPECTED_FROM_L1_KASS_ONLY');
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
  fn constructor(
      ref self: ContractState,
      owner_: starknet::ContractAddress,
      l1_kass_address_: starknet::EthAddress,
      token_implementation_: starknet::ClassHash,
      erc721_implementation_: starknet::ClassHash,
      erc1155_implementation_: starknet::ClassHash
    ) {
      self.initializer(
        :owner_,
        :l1_kass_address_,
        :token_implementation_,
        :erc721_implementation_,
        :erc1155_implementation_
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

    fn request_ownership(
      ref self: ContractState,
      l2_token_address: starknet::ContractAddress,
      l1_owner: starknet::EthAddress
    ) {
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      // assert L2 token owner is sender
      let caller = starknet::get_caller_address();
      let l2_owner = IOwnableDispatcher { contract_address: l2_token_address }.owner();

      assert(caller == l2_owner, 'Caller is not the owner');

      // send L2 wrapper request message
      kass_messaging_self._send_l1_ownership_request_message(token_address: l2_token_address, :l1_owner);

      // emit event
      self.emit(
        Event::OwnershipRequest(
          OwnershipRequest { l2_token_address, l1_owner }
        )
      )
    }

    fn deposit_721(
      ref self: ContractState,
      native_token_address: felt252,
      recipient: starknet::EthAddress,
      token_id: u256,
      request_wrapper: bool
    ) {
      self._deposit(:native_token_address, :recipient, :token_id, amount: u256 { low: 1, high: 0 }, :request_wrapper);
    }

    fn deposit_1155(
      ref self: ContractState,
      native_token_address: felt252,
      recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256,
      request_wrapper: bool
    ) {
      self._deposit(:native_token_address, :recipient, :token_id, :amount, :request_wrapper);
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
  // IKassTokenDeployer impl
  //

  impl IKassTokenDeployerImpl of bridge::interface::IKassTokenDeployer<ContractState> {
    fn token_implementation(self: @ContractState) -> starknet::ClassHash {
      let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.token_implementation()
    }

    fn erc721_implementation(self: @ContractState) -> starknet::ClassHash {
      let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.erc721_implementation()
    }

    fn erc1155_implementation(self: @ContractState) -> starknet::ClassHash {
      let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.erc1155_implementation()
    }

    fn l2_kass_token_address(
      self: @ContractState,
      l1_token_address: starknet::EthAddress
    ) -> starknet::ContractAddress {
      let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.l2_kass_token_address(:l1_token_address)
    }

    fn compute_l2_kass_token_address(
      self: @ContractState,
      l1_token_address: starknet::EthAddress
    ) -> starknet::ContractAddress {
      let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.compute_l2_kass_token_address(:l1_token_address)
    }

    fn set_deployer_class_hashes(
      ref self: ContractState,
      token_implementation_: starknet::ClassHash,
      erc721_implementation_: starknet::ClassHash,
      erc1155_implementation_: starknet::ClassHash
    ) {
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      kass_token_deployer_self.set_deployer_class_hashes(
        :token_implementation_,
        :erc721_implementation_,
        :erc1155_implementation_
      );
    }
  }

  //
  // Handlers
  //

  // Wrapper creation

  #[l1_handler]
  impl IKassBridgeHandlersImpl of bridge::interface::IKassBridgeHandlers<ContractState> {

    // Ownership claim

    fn claim_ownership(
      ref self: ContractState,
      from_address: starknet::EthAddress,
      l1_token_address: starknet::EthAddress,
      owner: starknet::ContractAddress
    ) {
      // Modifiers
      self._l1_handler(from_address);

      // Body
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

      // get L2 token wrapper
      let l2_token_address = kass_token_deployer_self.l2_kass_token_address(:l1_token_address);

      // transfer ownership
      IOwnableDispatcher { contract_address: l2_token_address }.transfer_ownership(owner);

      // emit event
      self.emit(
        Event::OwnershipClaim(
          OwnershipClaim { l1_token_address, l2_token_address, l2_owner: owner }
        )
      )
    }

    fn withdraw_721(
      ref self: ContractState,
      from_address: starknet::EthAddress,
      native_token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
      calldata: Span<felt252>
    ) {
      // Modifiers
      self._l1_handler(from_address);

      // body
      self._withdraw(
        :native_token_address,
        :recipient,
        :token_id,
        :amount,
        :calldata,
        token_standard: TokenStandard::ERC721(())
      );
    }

    fn withdraw_1155(
      ref self: ContractState,
      from_address: starknet::EthAddress,
      native_token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
      calldata: Span<felt252>
    ) {
      // modifiers
      self._l1_handler(from_address);

      // body
      self._withdraw(
        :native_token_address,
        :recipient,
        :token_id,
        :amount,
        :calldata,
        token_standard: TokenStandard::ERC1155(())
      );
    }
  }

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
      let contractAddress = starknet::get_contract_address();

      // validate transfer only if it's executed in the context of a deposit
      if (contractAddress == operator) {
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
      let contractAddress = starknet::get_contract_address();

      // validate transfer only if it's executed in the context of a deposit
      if (contractAddress == operator) {
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

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(
      ref self: ContractState,
      owner_: starknet::ContractAddress,
      l1_kass_address_: starknet::EthAddress,
      token_implementation_: starknet::ClassHash,
      erc721_implementation_: starknet::ClassHash,
      erc1155_implementation_: starknet::ClassHash
    ) {
      let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();
      let mut ownable_self = Ownable::unsafe_new_contract_state();

      kass_messaging_self.set_l1_kass_address(:l1_kass_address_);

      kass_token_deployer_self.set_deployer_class_hashes(
        :token_implementation_,
        :erc721_implementation_,
        :erc1155_implementation_
      );

      ownable_self._transfer_ownership(new_owner: owner_);
    }

    // Native/wrapper mgmt

    fn _parse_native_token_address(
      self: @ContractState,
      native_token_address: felt252
    ) -> (starknet::ContractAddress, bool) {
      let castedNativeTokenAddress: starknet::ContractAddress = native_token_address.try_into().unwrap();

      if (castedNativeTokenAddress.is_deployed()) {
        (castedNativeTokenAddress, true)
      } else {
        let kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

        (kass_token_deployer_self.l2_kass_token_address(native_token_address.try_into().unwrap()), false)
      }
    }

    // Deposit

    fn _deposit(
      ref self: ContractState,
      native_token_address: felt252,
      recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256,
      request_wrapper: bool
    ) {
      let mut kass_messaging_self = KassMessaging::unsafe_new_contract_state();

      // get l1 token address (native or wrapper)
      let (l2_token_address, is_l2_native) = self._parse_native_token_address(:native_token_address);

      // avoid double wrap
      assert(is_l2_native | request_wrapper == false, 'Double wrap not allowed');

      // burn or tranfer tokens
      self._lockTokens(token_address: l2_token_address, :token_id, :amount, is_native: is_l2_native);

      // send l1 deposit message
      kass_messaging_self._send_token_deposit_message(
        :native_token_address,
        :recipient,
        :token_id,
        :amount,
        :request_wrapper
      );

      // emit events
      if (request_wrapper) {
        self.emit(
          Event::WrapperRequest(
            WrapperRequest { l2_token_address }
          )
        );
      }

      let caller = starknet::get_caller_address();
      self.emit(
        Event::Deposit(
          Deposit { native_token_address, sender: caller, recipient, token_id, amount }
        )
      );
    }

    // Withdraw

    fn _withdraw(
      ref self: ContractState,
      native_token_address: felt252,
      recipient: starknet::ContractAddress,
      token_id: u256,
      amount: u256,
      calldata: Span<felt252>,
      token_standard: TokenStandard
    ) {
      // get l1 token address (native or wrapper)
      let (l2_token_address, is_l2_native) = self._parse_native_token_address(:native_token_address);

      if (!l2_token_address.is_deployed()) {
        assert(calldata.len().is_non_zero(), 'Wrapper not deployed');

        // deploy Kass ERC-721/1155
        let mut kass_token_deployer_self = KassTokenDeployer::unsafe_new_contract_state();

        let l1_token_address: starknet::EthAddress = native_token_address.try_into().unwrap();

        match token_standard {
          TokenStandard::ERC721(()) => {
            let l2_token_address = kass_token_deployer_self._deploy_kass_erc721(:l1_token_address, :calldata);
          },
          TokenStandard::ERC1155(()) => {
            let l2_token_address = kass_token_deployer_self._deploy_kass_erc1155(:l1_token_address, :calldata);
          },
        };

        // emit event
        self.emit(
          Event::WrapperCreation(
            WrapperCreation { l1_token_address, l2_token_address }
          )
        )
      }

      // mint or tranfer tokens
      self._unlockTokens(token_address: l2_token_address, :recipient, :token_id, :amount, is_native: is_l2_native);

      // emit event
      self.emit(
        Event::Withdraw(
          Withdraw { native_token_address, recipient, token_id, amount }
        )
      )
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
        if (is_native) {
          let ERC721 = DualCaseERC721 { contract_address: token_address };

          ERC721.transfer_from(from: caller, to: contractAddress, :token_id);
        } else {
          let KassERC721 = KassERC721ABIDispatcher { contract_address: token_address };

          // check if caller is owner before burning
          assert(KassERC721.owner_of(:token_id) == caller, 'You do not own this token');

          KassERC721.permissioned_burn(:token_id);
        }

        return ();
      } else if (token_address.isERC1155()) {
        assert(amount > u256 {low: 0, high: 0 }, 'Cannot deposit null amount');

        if (is_native) {
          let ERC1155 = DualCaseERC1155 { contract_address: token_address };

          ERC1155.safe_transfer_from(
            from: caller,
            to: contractAddress,
            id: token_id,
            :amount,
            data: ArrayTrait::new().span()
          );
        } else {
          let KassERC1155 = KassERC1155ABIDispatcher { contract_address: token_address };

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
        if (is_native) {
          let ERC721 = DualCaseERC721 { contract_address: token_address };

          ERC721.transfer_from(from: contractAddress, to: recipient, :token_id);
        } else {
          let KassERC721 = KassERC721ABIDispatcher { contract_address: token_address };

          KassERC721.permissioned_mint(to: recipient, :token_id);
        }

        return ();
      } else if (token_address.isERC1155()) {
        assert(amount > u256 {low: 0, high: 0 }, 'Cannot withdraw null amount');

        let KassERC1155 = KassERC1155ABIDispatcher { contract_address: token_address };

        if (is_native) {
          let ERC1155 = DualCaseERC1155 { contract_address: token_address };

          ERC1155.safe_transfer_from(
            from: contractAddress,
            to: recipient,
            id: token_id,
            :amount,
            data: ArrayTrait::new().span()
          );
        } else {
          let KassERC1155 = KassERC1155ABIDispatcher { contract_address: token_address };

          KassERC1155.permissioned_mint(to: recipient, id: token_id, :amount);
        }

        return ();
      } else {
        panic_with_felt252('Kass: Unkown token standard');
      }
    }
  }
}
