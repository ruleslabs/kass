use debug::PrintTrait;
use array::{ ArrayTrait, SpanSerde };
use serde::Serde;
use traits::{ Into, TryInto };
use option::OptionTrait;
use starknet::testing;
use starknet::class_hash::Felt252TryIntoClassHash;
use rules_utils::utils::partial_eq::SpanPartialEq;
use rules_utils::utils::serde::SerdeTraitExt;
  use rules_utils::utils::array::ArrayTraitExt;

// locals
use kass::bridge::interface::IKassMessaging;

use kass::bridge::messaging::KassMessaging;
use kass::bridge::messaging::KassMessaging::{
  InternalTrait as KassMessagingInternalTrait,
  CLAIM_OWNERSHIP,
  DEPOSIT_TO_L1,
  DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1,
  DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1,
};

use super::mocks::erc721_mock::ERC721Mock;
use super::mocks::erc1155_mock::ERC1155Mock;

use super::constants;

use super::utils;

//
// Setup
//

fn setup() -> KassMessaging::ContractState {
  let kass_messaging = KassMessaging::unsafe_new_contract_state();

  kass_messaging
}

fn setup_erc721() -> starknet::ContractAddress {
  let calldata = array![constants::L1_TOKEN_NAME, constants::L1_TOKEN_SYMBOL];

  let token_address = utils::deploy(ERC721Mock::TEST_CLASS_HASH, calldata);

  token_address
}

fn setup_erc1155() -> starknet::ContractAddress {
  let mut calldata = array![];
  calldata.append_serde(constants::L1_TOKEN_URI());

  let token_address = utils::deploy(ERC1155Mock::TEST_CLASS_HASH, calldata);

  token_address
}

//
// Tests
//

// Ownership request

#[test]
#[available_gas(20000000)]
fn test_request_ownership_payload() {
  let kass_messaging = setup();

  let l1_owner = constants::L1_OTHER();
  let token_address = constants::L2_TOKEN_ADDRESS();

  let expected_payload = array![
    CLAIM_OWNERSHIP.into(),
    token_address.into(),
    l1_owner.into(),
  ].span();

  let payload = kass_messaging._compute_l1_ownership_request(:token_address, :l1_owner).span();

  assert(payload == expected_payload, 'Invalid payload');
}

// Deposit

#[test]
#[available_gas(20000000)]
fn test_deposit_payload() {
  let kass_messaging = setup();

  let native_token_address: felt252 = constants::L2_TOKEN_ADDRESS().into();
  let recipient = constants::L1_OTHER();
  let token_id = constants::TOKEN_ID;
  let amount = constants::AMOUNT;
  let request_wrapper = false;

  let expected_payload = array![
    DEPOSIT_TO_L1.into(),
    native_token_address,
    recipient.into(),
    token_id.low.into(),
    token_id.high.into(),
    amount.low.into(),
    amount.high.into(),
  ].span();

  let payload = kass_messaging._compute_token_deposit_on_l1_message(
    :native_token_address,
    :recipient,
    :token_id,
    :amount,
    :request_wrapper
  ).span();

  assert(payload == expected_payload, 'Invalid payload');
}

#[test]
#[available_gas(20000000)]
fn test_deposit_payload_with_huge_variables() {
  let kass_messaging = setup();

  let native_token_address: felt252 = constants::L2_TOKEN_ADDRESS().into();
  let recipient = constants::L1_OTHER();
  let token_id = constants::HUGE_TOKEN_ID;
  let amount = constants::HUGE_AMOUNT;
  let request_wrapper = false;

  let expected_payload = array![
    DEPOSIT_TO_L1.into(),
    native_token_address,
    recipient.into(),
    token_id.low.into(),
    token_id.high.into(),
    amount.low.into(),
    amount.high.into(),
  ].span();

  let payload = kass_messaging._compute_token_deposit_on_l1_message(
    :native_token_address,
    :recipient,
    :token_id,
    :amount,
    :request_wrapper
  ).span();

  assert(payload == expected_payload, 'Invalid payload');
}

#[test]
#[available_gas(20000000)]
fn test_deposit_with_erc721_wrapper_request_payload() {
  let kass_messaging = setup();
  let erc721_token_address = setup_erc721();

  let native_token_address: felt252 = erc721_token_address.into();
  let recipient = constants::L1_OTHER();
  let token_id = constants::HUGE_TOKEN_ID;
  let amount = constants::HUGE_AMOUNT;
  let request_wrapper = true;

  let expected_payload = array![
    DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1.into(),
    native_token_address,
    recipient.into(),
    token_id.low.into(),
    token_id.high.into(),
    amount.low.into(),
    amount.high.into(),
    constants::L1_TOKEN_NAME,
    constants::L1_TOKEN_SYMBOL,
  ].span();

  let payload = kass_messaging._compute_token_deposit_on_l1_message(
    :native_token_address,
    :recipient,
    :token_id,
    :amount,
    :request_wrapper
  ).span();

  assert(payload == expected_payload, 'Invalid payload');
}

#[test]
#[available_gas(20000000)]
fn test_deposit_with_erc1155_wrapper_request_payload() {
  let kass_messaging = setup();
  let erc1155_token_address = setup_erc1155();

  let native_token_address: felt252 = erc1155_token_address.into();
  let recipient = constants::L1_OTHER();
  let token_id = constants::HUGE_TOKEN_ID;
  let amount = constants::HUGE_AMOUNT;
  let request_wrapper = true;

  let mut expected_payload = array![
    DEPOSIT_AND_REQUEST_1155_WRAPPER_TO_L1.into(),
    native_token_address,
    recipient.into(),
    token_id.low.into(),
    token_id.high.into(),
    amount.low.into(),
    amount.high.into(),
  ];

  expected_payload = expected_payload.concat(constants::L1_TOKEN_URI().snapshot);

  let payload = kass_messaging._compute_token_deposit_on_l1_message(
    :native_token_address,
    :recipient,
    :token_id,
    :amount,
    :request_wrapper
  ).span();

  assert(payload == expected_payload.span(), 'Invalid payload');
}
