use traits::{ TryInto, Into };
use result::ResultTrait;
use array::ArrayTrait;
use debug::PrintTrait;
use option::OptionTrait;
use starknet::testing;
use starknet::EthAddressIntoFelt252;
use rules_utils::utils::serde::SerdeTraitExt;
use rules_utils::utils::partial_eq::SpanPartialEq;

// locals
use kass::bridge::interface::{ IKassBridge, IKassMessaging, IKassTokenDeployer };
use kass::bridge::bridge::KassBridge;
use kass::bridge::bridge::KassBridge::{
  InternalTrait as KassBridgeInternalTrait,
  UpgradeTrait as KassBridgeUpgradeTrait,
};
use kass::bridge::token_standard::TokenStandard;

use kass::factory::common::KassToken;
use kass::factory::erc721::KassERC721;
use kass::factory::erc1155::KassERC1155;

use super::mocks::account::Account;

use super::utils;

// Dispatchers
use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };
use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };

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

fn OTHER() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x20>()
}

fn BRIDGE() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x30>()
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

// L1 token

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

//
// Setup
//

fn setup() -> KassBridge::ContractState {
  setup_owner();

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
