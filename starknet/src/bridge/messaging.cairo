use core::traits::TryInto;


#[starknet::contract]
mod KassMessaging {
  use starknet::ContractAddressIntoFelt252;
  use zeroable::Zeroable;
  use array::ArrayTrait;
  use traits::{ Into, TryInto };
  use option::OptionTrait;
  use starknet::EthAddressZeroable;
  use rules_utils::utils::array::ArrayTraitExt;

  // Dispatchers
  use rules_erc721::erc721::erc721::{ ERC721ABIDispatcher, ERC721ABIDispatcherTrait };
  use rules_erc1155::erc1155::erc1155::{ ERC1155ABIDispatcher, ERC1155ABIDispatcherTrait };

  // locals
  use kass::bridge;
  use kass::bridge::token_standard::{ TokenStandard, ContractAddressInterfacesTrait };
  use kass::bridge::interface::IKassMessaging;

  const DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1: u32 = 0x954f1a23;
  const DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1: u32 = 0x21deb3de;

  const CLAIM_OWNERSHIP: u32 = 0xa19646f5;

  const DEPOSIT_TO_L1: u32 = 0x93dfc08b;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    // L1 Address of the Kass contract
    _l1_kass_address: starknet::EthAddress,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState) { }

  //
  // IKassMessaging impl
  //

  impl IKassMessagingImpl of bridge::interface::IKassMessaging<ContractState> {
    fn l1_kass_address(self: @ContractState) -> starknet::EthAddress {
      self._l1_kass_address.read()
    }

    fn set_l1_kass_address(ref self: ContractState, l1_kass_address_: starknet::EthAddress) {
      assert(l1_kass_address_.is_non_zero(), 'ZERO_L1_KASS_ADDRESS');

      self._l1_kass_address.write(l1_kass_address_);
    }
  }

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {

    // Send messages

    fn _send_l1_ownership_request_message(
      ref self: ContractState,
      token_address: starknet::ContractAddress,
      l1_owner: starknet::EthAddress
    ) {
      let payload = self._compute_l1_ownership_request(:token_address, :l1_owner);

      // send ownership request to L1
      starknet::syscalls::send_message_to_l1_syscall(
        to_address: self.l1_kass_address().into(),
        payload: payload.span()
      );
    }

    fn _send_token_deposit_message(
      ref self: ContractState,
      native_token_address: felt252,
      recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256,
      request_wrapper: bool
    ) {
      let payload = self._compute_token_deposit_on_l1_message(
        :native_token_address,
        :recipient,
        :token_id,
        :amount,
        :request_wrapper
      );

      // send deposit request to L1
      starknet::syscalls::send_message_to_l1_syscall(
        to_address: self.l1_kass_address().into(),
        payload: payload.span()
      );
    }

    // L1 OWNERSHIP REQUEST

    fn _compute_l1_ownership_request(
      self: @ContractState,
      token_address: starknet::ContractAddress,
      l1_owner: starknet::EthAddress
    ) -> Array<felt252> {
      let mut payload: Array<felt252> = ArrayTrait::new();

      payload.append(CLAIM_OWNERSHIP.into());

      payload.append(token_address.into());

      payload.append(l1_owner.into());

      return payload;
    }

    // DEPOSIT ON L1

    fn _compute_token_deposit_on_l1_message(
      self: @ContractState,
      native_token_address: felt252,
      recipient: starknet::EthAddress,
      token_id: u256,
      amount: u256,
      request_wrapper: bool
    ) -> Array<felt252> {
      let mut payload: Array<felt252> = ArrayTrait::new();

      if (request_wrapper) {

        let token_address: starknet::ContractAddress = native_token_address.try_into().unwrap();

        if (token_address.isERC721()) {

          // token is ERC721

          payload.append(DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1.into());

          // store L2 token address
          payload.append(token_address.into());

          // store wrapper init calldata
          let ERC721 = ERC721ABIDispatcher { contract_address: token_address };

          payload.append(ERC721.name());
          payload.append(ERC721.symbol());
        } else if (token_address.isERC1155()) {

          // token is ERC1155

          payload.append(DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1.into());

          // store L2 token address
          payload.append(token_address.into());

          // store wrapper init calldata
          let ERC1155 = ERC1155ABIDispatcher { contract_address: token_address };
          let mut uri = ERC1155.uri(0.into());

          payload = payload.concat(uri.snapshot);
        } else {
          panic_with_felt252('Kass: Unkown token standard');
        }
      } else {
        payload.append(DEPOSIT_TO_L1.into());
      }


      payload.append(native_token_address);

      payload.append(recipient.into());

      payload.append(token_id.low.into());
      payload.append(token_id.high.into());

      payload.append(amount.low.into());
      payload.append(amount.high.into());

      return payload;
    }
  }
}
