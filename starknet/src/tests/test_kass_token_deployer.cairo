use array::{ ArrayTrait, SpanSerde };
use serde::Serde;
use traits::{ Into, TryInto };
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use rules_utils::utils::partial_eq::SpanPartialEq;

// locals
use kass::bridge::interface::IKassTokenDeployer;

use kass::bridge::token_deployer::KassTokenDeployer;
use kass::bridge::token_deployer::KassTokenDeployer::{ ContractState as KassTokenDeployerContractState };

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

// SALT

fn SALT() -> felt252 {
  L1_TOKEN_ADDRESS().into()
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

// SETUP

fn setup() -> KassTokenDeployerContractState {
  let kass_token_deployer = KassTokenDeployer::unsafe_new_contract_state();

  kass_token_deployer
}

fn setup_with_class_hashes() -> KassTokenDeployerContractState {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_address_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_address_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC1155_CLASS_HASH(),
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
    token_implementation_address_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_address_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid token implementation',))]
fn test_set_deployer_class_hashes_invalid_token() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_address_: Zeroable::<starknet::ClassHash>::zero(),
    erc721_implementation_address_: KASS_ERC1155_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid ERC721 implementation',))]
fn test_set_deployer_class_hashes_invalid_erc721() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_address_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_address_: KASS_ERC1155_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid ERC1155 implementation',))]
fn test_set_deployer_class_hashes_invalid_erc1155() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    token_implementation_address_: KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_address_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC721_CLASS_HASH(),
  );
}

// DEPLOYER KASS ERC721

#[test]
#[available_gas(20000000)]
fn test_deployer_kass_erc721() {
  let mut kass_token_deployer = setup_with_class_hashes();

  let name = ERC721_NAME();
  let symbol = ERC721_SYMBOL();

  let salt = SALT();
  let calldata = ERC721_CALLDATA().span();

  let kass_erc721_contract_address = kass_token_deployer.deploy_kass_erc721(:salt, :calldata);
  let kass_erc721_contract = KassERC721ABIDispatcher { contract_address: kass_erc721_contract_address };

  assert(kass_erc721_contract.name() == name, 'Invalid ERC721 name');
  assert(kass_erc721_contract.symbol() == symbol, 'Invalid ERC721 symbol');
}

// DEPLOYER KASS ERC1155

#[test]
#[available_gas(20000000)]
fn test_deployer_kass_erc1155() {
  let mut kass_token_deployer = setup_with_class_hashes();

  let uri = ERC1155_URI();

  let salt = SALT();
  let calldata = ERC1155_CALLDATA().span();

  let kass_erc1155_contract_address = kass_token_deployer.deploy_kass_erc1155(:salt, :calldata);
  let kass_erc1155_contract = KassERC1155ABIDispatcher { contract_address: kass_erc1155_contract_address };

  assert(kass_erc1155_contract.uri(token_id: 0) == uri.span(), 'Invalid ERC1155 uri');
}
