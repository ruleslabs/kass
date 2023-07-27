use traits::{ TryInto, Into };
use result::ResultTrait;
use array::{ ArrayTrait, SpanTrait };
use debug::PrintTrait;
use option::OptionTrait;
use starknet::testing;
use starknet::EthAddressIntoFelt252;
use rules_utils::utils::serde::SerdeTraitExt;
use rules_utils::utils::partial_eq::SpanPartialEq;
use rules_utils::utils::contract_address::ContractAddressTraitExt;
use test::test_utils::assert_eq;

// Dispatchers
use rules_erc721::erc721::interface::{ IERC721Dispatcher, IERC721DispatcherTrait };
use rules_erc1155::erc1155::interface::{ IERC1155Dispatcher, IERC1155DispatcherTrait };

// locals
use kass::bridge::interface::{ IKassBridge, IKassMessaging, IKassTokenDeployer };
use kass::bridge::bridge::KassBridge;
use kass::bridge::bridge::KassBridge::{
  InternalTrait as KassBridgeInternalTrait,
  UpgradeTrait as KassBridgeUpgradeTrait,
};
use kass::bridge::token_standard::TokenStandard;
use kass::bridge::messaging::KassMessaging::{ DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1, DEPOSIT_TO_L1 };

use kass::factory::common::KassToken;
use kass::factory::erc721::KassERC721;
use kass::factory::erc1155::KassERC1155;

use super::mocks::account::Account;
use super::mocks::erc721_mock::ERC721Mock;
use super::mocks::erc1155_mock::ERC1155Mock;
use super::mocks::bridge_receiver::BridgeReceiverMock;

use super::utils;

// Dispatchers
use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };
use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };
use super::mocks::erc721_mock::{ IERC721MockDispatcher, IERC721MockDispatcherTrait };
use super::mocks::erc1155_mock::{ IERC1155MockDispatcher, IERC1155MockDispatcherTrait };

//
// Constants
//

// addresses

fn ZERO() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x0>()
}

fn OWNER() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x1>()
}

fn BRIDGE() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x2>()
}

fn L2_NATIVE_TOKEN_ADDRESS() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x3>()
}

fn OTHER() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x20>()
}

// eth addresses

fn L1_OTHER() -> starknet::EthAddress {
  0x10.try_into().unwrap()
}

// L1 kass

fn L1_KASS_ADDRESS() -> starknet::EthAddress {
  'l1 kass address'.try_into().unwrap()
}

fn L1_KASS_ADDRESS_2() -> starknet::EthAddress {
  'l1 kass address 2'.try_into().unwrap()
}

// ERC721

const L1_TOKEN_NAME: felt252 = 'L2 Kass Token';
const L1_TOKEN_SYMBOL: felt252 = 'L2KT';

fn L1_ERC721_TOKEN_CALLDATA() -> Span<felt252> {
  array![L1_TOKEN_NAME, L1_TOKEN_SYMBOL].span()
}

// ERC1155

fn L1_TOKEN_URI() -> Span<felt252> {
  array![111, 222, 333].span()
}

fn L1_ERC1155_TOKEN_CALLDATA() -> Span<felt252> {
  let mut calldata = array![];

  calldata.append_serde(L1_TOKEN_URI());

  calldata.span()
}

// L1 token contract

fn L1_TOKEN_CALLDATA(token_standard: TokenStandard) -> Span<felt252> {
  match token_standard {
    TokenStandard::ERC721(()) => {
      L1_ERC721_TOKEN_CALLDATA()
    },
    TokenStandard::ERC1155(()) => {
      L1_ERC1155_TOKEN_CALLDATA()
    },
  }
}

fn L1_TOKEN_ADDRESS() -> starknet::EthAddress {
  'l1 address'.try_into().unwrap()
}

// Token

const TOKEN_ID: u256 = 'token id';
const HUGE_TOKEN_ID: u256 = '======== huge token id ========';

const AMOUNT: u256 = 'amount';
const HUGE_AMOUNT: u256 = '======== huge amount ========';

// implementation

fn KASS_TOKEN_CLASS_HASH() -> starknet::ClassHash {
  KassToken::TEST_CLASS_HASH.try_into().unwrap()
}

fn KASS_ERC721_CLASS_HASH() -> starknet::ClassHash {
  KassERC721::TEST_CLASS_HASH.try_into().unwrap()
}

fn KASS_ERC1155_CLASS_HASH() -> starknet::ClassHash {
  KassERC1155::TEST_CLASS_HASH.try_into().unwrap()
}

// Payloads

fn L2_NATIVE_ERC721_DEPOSIT_PAYLOAD() -> Span<felt252> {
  let amount: u256 = 0x1;

  array![
    DEPOSIT_TO_L1.into(),
    L2_NATIVE_TOKEN_ADDRESS().into(),
    L1_OTHER().into(),
    TOKEN_ID.low.into(),
    TOKEN_ID.high.into(),
    amount.low.into(),
    amount.high.into(),
  ].span()
}

fn L2_NATIVE_ERC721_DEPOSIT_WITH_WRAPPER_REQUEST_PAYLOAD() -> Span<felt252> {
  let amount: u256 = 0x1;

  array![
    DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1.into(),
    L2_NATIVE_TOKEN_ADDRESS().into(),
    L1_OTHER().into(),
    TOKEN_ID.low.into(),
    TOKEN_ID.high.into(),
    amount.low.into(),
    amount.high.into(),
    L1_TOKEN_NAME,
    L1_TOKEN_SYMBOL,
  ].span()
}

// Logs

fn L2_NATIVE_ERC721_DEPOSIT_LOG() -> KassBridge::Event {
  let amount: u256 = 0x1;

  KassBridge::Event::Deposit(
    KassBridge::Deposit {
      native_token_address: L2_NATIVE_TOKEN_ADDRESS().into(),
      sender: OWNER(),
      recipient: L1_OTHER(),
      token_id: TOKEN_ID,
      amount,
    }
  )
}

fn L2_NATIVE_WRAPPER_REQUEST_LOG() -> KassBridge::Event {
  KassBridge::Event::WrapperRequest(
    KassBridge::WrapperRequest { l2_token_address: L2_NATIVE_TOKEN_ADDRESS() }
  )
}

//
// Setup
//

fn setup() -> KassBridge::ContractState {
  setup_owner();
  setup_bridge_receiver();

  let mut kass = KassBridge::unsafe_new_contract_state();

  testing::set_caller_address(OWNER());
  testing::set_contract_address(BRIDGE());

  kass.initializer(
    owner_: OWNER(),
    l1_kass_address_: L1_KASS_ADDRESS(),
    token_implementation_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC1155_CLASS_HASH(),
  );

  kass
}

fn setup_owner() {
  let owner_address = utils::deploy(Account::TEST_CLASS_HASH, array![]);

  assert(owner_address == OWNER(), 'Invalid owner address');
}

fn setup_bridge_receiver() {
  let bridge_receiver_address = utils::deploy(BridgeReceiverMock::TEST_CLASS_HASH, array![]);

  assert(bridge_receiver_address == BRIDGE(), 'Invalid bridge receiver address');
}

// setup wrapper

fn _setup_wrapper(
  ref kass: KassBridge::ContractState,
  token_standard: TokenStandard,
  token_id: u256,
  amount: u256
) -> starknet::ContractAddress {
  let l2_recipient = OWNER();
  let native_token_address: felt252 = L1_TOKEN_ADDRESS().into();

  let calldata = L1_TOKEN_CALLDATA(:token_standard);

  // update caller addr
  testing::set_caller_address(BRIDGE());

  kass._withdraw(
    :native_token_address,
    recipient: l2_recipient,
    :token_id,
    :amount,
    :calldata,
    :token_standard
  );

  // reset caller addr back to owner
  testing::set_caller_address(OWNER());

  kass.l2_kass_token_address(l1_token_address: L1_TOKEN_ADDRESS())
}

fn setup_erc721_wrapper(ref kass: KassBridge::ContractState) -> KassERC721ABIDispatcher {
  let wrapper_address = _setup_wrapper(
    ref kass: kass,
    token_standard: TokenStandard::ERC721(()),
    token_id: 'wrapper request tokenId',
    amount: 0x1
  );

  KassERC721ABIDispatcher { contract_address: wrapper_address }
}

fn setup_erc721_wrapper_with_token(ref kass: KassBridge::ContractState, token_id: u256) -> KassERC721ABIDispatcher {
  let wrapper_address = _setup_wrapper(
    ref kass: kass,
    token_standard: TokenStandard::ERC721(()),
    :token_id,
    amount: 0x1
  );

  KassERC721ABIDispatcher { contract_address: wrapper_address }
}

fn setup_erc1155_wrapper(ref kass: KassBridge::ContractState) -> KassERC1155ABIDispatcher {
  let wrapper_address = _setup_wrapper(
    ref kass: kass,
    token_standard: TokenStandard::ERC1155(()),
    token_id: 'wrapper request tokenId',
    amount: 0x1
  );

  KassERC1155ABIDispatcher { contract_address: wrapper_address }
}

fn setup_erc1155_wrapper_with_token(
  ref kass: KassBridge::ContractState,
  token_id: u256,
  amount: u256
) -> KassERC1155ABIDispatcher {
  let wrapper_address = _setup_wrapper(ref kass: kass, token_standard: TokenStandard::ERC1155(()), :token_id, :amount);

  KassERC1155ABIDispatcher { contract_address: wrapper_address }
}

// Native tokens

fn setup_erc721() -> IERC721Dispatcher {
  let calldata = array![L1_TOKEN_NAME, L1_TOKEN_SYMBOL];

  // avoid pushing logs
  testing::set_contract_address(OWNER());

  let token_address = utils::deploy(ERC721Mock::TEST_CLASS_HASH, calldata);

  assert(token_address == L2_NATIVE_TOKEN_ADDRESS(), 'Invalid token address');

  let erc721_mock = IERC721MockDispatcher{ contract_address: token_address };

  // mint and approve tokens

  erc721_mock.mint(token_id: TOKEN_ID);
  erc721_mock.mint(token_id: HUGE_TOKEN_ID);

  let erc721 = IERC721Dispatcher { contract_address: token_address };

  erc721.approve(to: BRIDGE(), token_id: TOKEN_ID);
  erc721.approve(to: BRIDGE(), token_id: HUGE_TOKEN_ID);

  testing::set_contract_address(BRIDGE());

  erc721
}

fn setup_erc1155() -> IERC1155Dispatcher {
  let mut calldata = array![];
  calldata.append_serde(L1_TOKEN_URI());

  let token_address = utils::deploy(ERC1155Mock::TEST_CLASS_HASH, calldata);

  assert(token_address == L2_NATIVE_TOKEN_ADDRESS(), 'Invalid token address');

  let erc1155_mock = IERC1155MockDispatcher{ contract_address: token_address };

  // mint and approve tokens
  testing::set_contract_address(OWNER());

  erc1155_mock.mint(token_id: TOKEN_ID, amount: AMOUNT);
  erc1155_mock.mint(token_id: HUGE_TOKEN_ID, amount: HUGE_AMOUNT);

  let erc1155 = IERC1155Dispatcher { contract_address: token_address };

  erc1155.set_approval_for_all(operator: BRIDGE(), approved: true);

  testing::set_contract_address(BRIDGE());

  erc1155
}

//
// Tests
//

// l1_kass_address

#[test]
#[available_gas(20000000)]
fn test_l1_kass_address() {
  let mut kass = setup();

  assert(kass.l1_kass_address() == L1_KASS_ADDRESS(), 'Should be L1 kass addr');
}

// set_l1_kass_address

#[test]
#[available_gas(20000000)]
fn test_set_l1_kass_address() {
  let mut kass = setup();

  let new_l1_kass_address = L1_KASS_ADDRESS_2();

  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
  assert(kass.l1_kass_address() == new_l1_kass_address, 'Should be new L1 kass addr');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_set_l1_kass_address_unauthorized() {
  let mut kass = setup();

  let new_l1_kass_address = L1_KASS_ADDRESS_2();

  testing::set_caller_address(OTHER());
  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_set_l1_kass_address_from_zero() {
  let mut kass = setup();

  let new_l1_kass_address = L1_KASS_ADDRESS_2();

  testing::set_caller_address(ZERO());
  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
}

// upgrade

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_upgrade_unauthorized() {
  let mut kass = setup();

  testing::set_caller_address(OTHER());
  kass.upgrade(new_implementation: 'new implementation'.try_into().unwrap());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_upgrade_from_zero() {
  let mut kass = setup();

  testing::set_caller_address(ZERO());
  kass.upgrade(new_implementation: 'new implementation'.try_into().unwrap());
}

// ERC721 wrapper creation

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc721_creation() {
  let mut kass = setup();
  let kass_erc721 = setup_erc721_wrapper(ref kass: kass);

  assert(kass_erc721.name() == L1_TOKEN_NAME, 'Invalid token name');
  assert(kass_erc721.symbol() == L1_TOKEN_SYMBOL, 'Invalid token symbol');
}

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc721_creation_twice() {
  let mut kass = setup();
  setup_erc721_wrapper_with_token(ref kass: kass, token_id: 0x1);
  setup_erc721_wrapper_with_token(ref kass: kass, token_id: 0x2);
}

// ERC1155 wrapper creation

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc1155_creation() {
  let mut kass = setup();
  let kass_erc1155 = setup_erc1155_wrapper(ref kass: kass);

  assert(kass_erc1155.uri(token_id: 0x1) == L1_TOKEN_URI(), 'Invalid token uri');
}

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc1155_creation_twice() {
  let mut kass = setup();
  setup_erc1155_wrapper(ref kass: kass);
  setup_erc1155_wrapper(ref kass: kass);
}

// ERC721 Wrapper request

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc721_request() {
  let mut kass = setup();
  let erc721 = setup_erc721();

  let token_id = TOKEN_ID;
  let amount: u256 = 0x1;
  let native_token_address: felt252 = erc721.contract_address.into();
  let sender = OWNER();
  let l1_recipient = L1_OTHER();
  let request_wrapper = true;

  kass.deposit_721(:native_token_address, recipient: l1_recipient, :token_id, :request_wrapper);

  assert_l2_native_erc721_deposit_happened(:request_wrapper);
}

// ERC1155 Wrapper request

// #[test]
// #[available_gas(20000000)]
// fn test_wrapped_erc1155_request() {
//   let mut kass = setup();
//   let erc1155 = setup_erc1155();

//   let token_id = TOKEN_ID;
//   let amount: u256 = AMOUNT;
//   let native_token_address: felt252 = erc1155.contract_address.into();
//   let sender = OWNER();
//   let l1_recipient = L1_OTHER();
//   let request_wrapper = true;

//   kass.deposit_1155(:native_token_address, recipient: l1_recipient, :token_id, :amount, :request_wrapper);

//   // TODO: check logs
// }

//
// Helpers
//

fn assert_l2_native_erc721_deposit_happened(request_wrapper: bool) {
  // assert message has been sent to L1
  let mut expected_payload = match request_wrapper {
    bool::False => L2_NATIVE_ERC721_DEPOSIT_PAYLOAD(),
    bool::True => L2_NATIVE_ERC721_DEPOSIT_WITH_WRAPPER_REQUEST_PAYLOAD(),
  };

  let (to_address, payload) = testing::pop_l2_to_l1_message(BRIDGE()).unwrap();

  assert(to_address == L1_KASS_ADDRESS().into(), 'msg wrong to_address');
  assert(payload == L2_NATIVE_ERC721_DEPOSIT_WITH_WRAPPER_REQUEST_PAYLOAD(), 'msg wrong payload');

  // assert logs have been emitted

  // pop ERC721 transfer log
  testing::pop_log_raw(BRIDGE());

  if (request_wrapper) {
    let expected_log = L2_NATIVE_WRAPPER_REQUEST_LOG();

    assert_eq(
      @testing::pop_log(BRIDGE()).unwrap(),
      @expected_log,
      'invalid wrapper request log'
    );
  }

  let expected_log = L2_NATIVE_ERC721_DEPOSIT_LOG();

  assert_eq(
    @testing::pop_log(BRIDGE()).unwrap(),
    @expected_log,
    'invalid deposit log'
  );
}
