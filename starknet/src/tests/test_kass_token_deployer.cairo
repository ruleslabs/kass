use debug::PrintTrait;
use array::{ ArrayTrait, SpanSerde };
use serde::Serde;
use traits::{ Into, TryInto };
use option::OptionTrait;
use starknet::testing;
use starknet::class_hash::Felt252TryIntoClassHash;
use rules_utils::utils::partial_eq::SpanPartialEq;

// locals
use kass::bridge::interface::IKassTokenDeployer;

use kass::bridge::token_deployer::KassTokenDeployer;
use kass::bridge::token_deployer::KassTokenDeployer::{
  ContractState as KassTokenDeployerContractState,
  InternalTrait as KassTokenDeployerInternalTrait,
};

use kass::factory::common::KassToken;
use kass::factory::erc721::KassERC721;
use kass::factory::erc1155::KassERC1155;

// Dispatchers
use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };
use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };

// CLASS HASHES

fn KASS_TOKEN_CLASS_HASH() -> starknet::ClassHash {
  KassToken::TEST_CLASS_HASH.try_into().unwrap()
}

fn KASS_ERC721_CLASS_HASH() -> starknet::ClassHash {
  KassERC721::TEST_CLASS_HASH.try_into().unwrap()
}

fn KASS_ERC1155_CLASS_HASH() -> starknet::ClassHash {
  KassERC1155::TEST_CLASS_HASH.try_into().unwrap()
}

// L1

fn L1_TOKEN_ADDRESS() -> starknet::EthAddress {
  'l1 address'.try_into().unwrap()
}

// L2

fn L2_TOKEN_ADDRESS() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x5a79f4188c8087e0c4d726b05e34467d22105ab6cb8d96f7320cdb645f92446>()
}

// ERC721 CALLDATA

fn ERC721_NAME() -> felt252 {
  'Kass ERC721'
}

fn ERC721_SYMBOL() -> felt252 {
  'K721'
}

fn ERC721_CALLDATA() -> Array<felt252> {
  let mut calldata = ArrayTrait::new();

  calldata.append(ERC721_NAME());
  calldata.append(ERC721_SYMBOL());

  calldata
}

// ERC1155 CALLDATA

fn ERC1155_URI() -> Array<felt252> {
  let mut uri = ArrayTrait::new();

  uri.append(111);
  uri.append(222);
  uri.append(333);

  uri
}

fn ERC1155_CALLDATA() -> Array<felt252> {
  let mut calldata = ArrayTrait::new();

  ERC1155_URI().span().serialize(ref output: calldata);

  calldata
}

// MISC

fn KASS_ADDRESS() -> starknet::ContractAddress {
  starknet::contract_address_const::<'kass address'>()
}

//
// Setup
//

fn setup() -> KassTokenDeployerContractState {
  let kass_token_deployer = KassTokenDeployer::unsafe_new_contract_state();

  kass_token_deployer
}

fn setup_with_class_hashes() -> KassTokenDeployerContractState {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC1155_CLASS_HASH(),
  );

  kass_token_deployer
}

//
// Tests
//

// SET DEPLOYER CLASS HASHES

#[test]
#[available_gas(20000000)]
fn test_set_deployer_class_hashes() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC1155_CLASS_HASH(),
  );

  assert(kass_token_deployer.token_implementation() == KASS_TOKEN_CLASS_HASH(), 'Invalid token implementation');
  assert(kass_token_deployer.erc721_implementation() == KASS_ERC721_CLASS_HASH(), 'Invalid erc721 implementation');
  assert(kass_token_deployer.erc1155_implementation() == KASS_ERC1155_CLASS_HASH(), 'Invalid erc115 implementation');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid token implementation',))]
fn test_set_deployer_class_hashes_invalid_token() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_: Zeroable::<starknet::ClassHash>::zero(),
    erc721_implementation_: KASS_ERC1155_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid ERC721 implementation',))]
fn test_set_deployer_class_hashes_invalid_erc721() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: KASS_ERC1155_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid ERC1155 implementation',))]
fn test_set_deployer_class_hashes_invalid_erc1155() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_: KASS_ERC721_CLASS_HASH(),
  );
}

// DEPLOYER KASS ERC721

#[test]
#[available_gas(20000000)]
fn test_deployer_kass_erc721() {
  let mut kass_token_deployer = setup_with_class_hashes();

  let name = ERC721_NAME();
  let symbol = ERC721_SYMBOL();

  let l1_token_address = L1_TOKEN_ADDRESS();
  let calldata = ERC721_CALLDATA().span();

  let kass_erc721_contract_address = kass_token_deployer._deploy_kass_erc721(:l1_token_address, :calldata);
  let kass_erc721_contract = KassERC721ABIDispatcher { contract_address: kass_erc721_contract_address };

  assert(
    kass_token_deployer.l2_kass_token_address(:l1_token_address) == kass_erc721_contract_address,
    'Invalid L2 token address'
  );

  assert(kass_erc721_contract.name() == name, 'Invalid ERC721 name');
  assert(kass_erc721_contract.symbol() == symbol, 'Invalid ERC721 symbol');
}

// DEPLOYER KASS ERC1155

#[test]
#[available_gas(20000000)]
fn test_deployer_kass_erc1155() {
  let mut kass_token_deployer = setup_with_class_hashes();

  let uri = ERC1155_URI();

  let l1_token_address = L1_TOKEN_ADDRESS();
  let calldata = ERC1155_CALLDATA().span();

  let kass_erc1155_contract_address = kass_token_deployer._deploy_kass_erc1155(:l1_token_address, :calldata);
  let kass_erc1155_contract = KassERC1155ABIDispatcher { contract_address: kass_erc1155_contract_address };

  assert(
    kass_token_deployer.l2_kass_token_address(:l1_token_address) == kass_erc1155_contract_address,
    'Invalid L2 token address'
  );

  assert(kass_erc1155_contract.uri(token_id: 0) == uri.span(), 'Invalid ERC1155 uri');
}

// COMPUTE KASS TOKEN ADDRESS

#[test]
#[available_gas(20000000)]
fn test_compute_l2_kass_token_address() {
  let mut kass_token_deployer = setup_with_class_hashes();

  let l1_token_address = L1_TOKEN_ADDRESS();
  let l2_token_address = L2_TOKEN_ADDRESS();

  testing::set_caller_address(address: KASS_ADDRESS());
  let computed_l2_token_address = kass_token_deployer.compute_l2_kass_token_address(:l1_token_address);

  // then
  assert(l2_token_address == computed_l2_token_address, 'Invalid computed address');
}
