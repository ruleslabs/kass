use traits::{ TryInto, Into };
use array::{ ArrayTrait };
use starknet::EthAddressIntoFelt252;
use option::OptionTrait;
use rules_utils::utils::serde::SerdeTraitExt;

// locals
use kass::bridge::token_standard::TokenStandard;

use kass::factory::common::KassToken;
use kass::factory::erc721::KassERC721;
use kass::factory::erc1155::KassERC1155;

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

// Addresses compute

fn KASS_ADDRESS() -> starknet::ContractAddress {
  starknet::contract_address_const::<'kass address'>()
}

fn L2_TOKEN_ADDRESS() -> starknet::ContractAddress {
  starknet::contract_address_const::<0x4b363aa4e91a06524f4e78a921c4bbf6d3dfdfb2585ef2f90c85afadbf9735f>()
}
