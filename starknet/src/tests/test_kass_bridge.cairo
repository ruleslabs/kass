use traits::{ TryInto, Into };
use result::ResultTrait;
use zeroable::Zeroable;
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

use kass::bridge::messaging::KassMessaging;
use kass::bridge::messaging::KassMessaging::{
  InternalTrait as KassMessagingInternalTrait,
  DEPOSIT_AND_REQUEST_721_WRAPPER_TO_L1,
  DEPOSIT_TO_L1,
};

use kass::factory::common::KassToken;
use kass::factory::erc721::KassERC721;
use kass::factory::erc1155::KassERC1155;

use super::mocks::account::Account;
use super::mocks::erc721_mock::ERC721Mock;
use super::mocks::erc1155_mock::ERC1155Mock;

use super::utils;

use super::constants;

// Dispatchers
use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };
use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };
use super::mocks::erc721_mock::{ IERC721MockDispatcher, IERC721MockDispatcherTrait };
use super::mocks::erc1155_mock::{ IERC1155MockDispatcher, IERC1155MockDispatcherTrait };

//
// Setup
//

fn setup() -> KassBridge::ContractState {
  setup_owner();
  setup_bridge_receiver();

  let mut kass = KassBridge::unsafe_new_contract_state();

  testing::set_caller_address(constants::OWNER());

  // avoid pushing logs
  testing::set_contract_address(constants::OWNER());

  kass.initializer(
    owner_: constants::OWNER(),
    l1_kass_address_: constants::L1_KASS_ADDRESS(),
    token_implementation_: constants::KASS_TOKEN_CLASS_HASH(),
    erc721_implementation_: constants::KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_: constants::KASS_ERC1155_CLASS_HASH()
  );

  // set contract address back to bridge
  testing::set_contract_address(constants::BRIDGE());

  kass
}

fn setup_owner() {
  let owner_address = utils::deploy(Account::TEST_CLASS_HASH, array![]);

  assert(owner_address == constants::OWNER(), 'Invalid owner address');
}

fn setup_bridge_receiver() {
  let calldata = array![
    constants::OWNER().into(),
    constants::L1_KASS_ADDRESS().into(),
    constants::KASS_TOKEN_CLASS_HASH().into(),
    constants::KASS_ERC721_CLASS_HASH().into(),
    constants::KASS_ERC1155_CLASS_HASH().into(),
  ];

  let bridge_receiver_address = utils::deploy(KassBridge::TEST_CLASS_HASH, calldata);

  // pop ownership transfer log
  testing::pop_log_raw(constants::BRIDGE());

  assert(bridge_receiver_address == constants::BRIDGE(), 'Invalid bridge receiver address');
}

// setup wrapper

fn _setup_wrapper(
  ref kass: KassBridge::ContractState,
  token_standard: TokenStandard,
  token_id: u256,
  amount: u256
) -> starknet::ContractAddress {
  let l2_recipient = constants::OWNER();
  let native_token_address: felt252 = constants::L1_TOKEN_ADDRESS().into();

  let calldata = constants::L1_TOKEN_CALLDATA(:token_standard);

  // update caller addr
  testing::set_caller_address(constants::BRIDGE());

  kass._withdraw(
    :native_token_address,
    recipient: l2_recipient,
    :token_id,
    :amount,
    :calldata,
    :token_standard
  );

  // reset caller addr back to owner
  testing::set_caller_address(constants::OWNER());

  kass.l2_kass_token_address(l1_token_address: constants::L1_TOKEN_ADDRESS())
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
  let calldata = array![constants::L1_TOKEN_NAME, constants::L1_TOKEN_SYMBOL];

  // avoid pushing logs
  testing::set_contract_address(constants::OWNER());

  let token_address = utils::deploy(ERC721Mock::TEST_CLASS_HASH, calldata);

  assert(token_address == constants::L2_NATIVE_TOKEN_ADDRESS(), 'Invalid token address');

  let erc721_mock = IERC721MockDispatcher{ contract_address: token_address };

  // mint and approve tokens

  erc721_mock.mint(token_id: constants::TOKEN_ID);
  erc721_mock.mint(token_id: constants::HUGE_TOKEN_ID);

  let erc721 = IERC721Dispatcher { contract_address: token_address };

  erc721.approve(to: constants::BRIDGE(), token_id: constants::TOKEN_ID);
  erc721.approve(to: constants::BRIDGE(), token_id: constants::HUGE_TOKEN_ID);

  // set contract address back to bridge
  testing::set_contract_address(constants::BRIDGE());

  erc721
}

fn setup_erc1155() -> IERC1155Dispatcher {
  let mut calldata = array![];
  calldata.append_serde(constants::L1_TOKEN_URI());

  // avoid pushing logs
  testing::set_contract_address(constants::OWNER());

  let token_address = utils::deploy(ERC1155Mock::TEST_CLASS_HASH, calldata);

  assert(token_address == constants::L2_NATIVE_TOKEN_ADDRESS(), 'Invalid token address');

  let erc1155_mock = IERC1155MockDispatcher{ contract_address: token_address };

  // mint and approve tokens

  erc1155_mock.mint(token_id: constants::TOKEN_ID, amount: constants::AMOUNT);
  erc1155_mock.mint(token_id: constants::HUGE_TOKEN_ID, amount: constants::HUGE_AMOUNT);

  let erc1155 = IERC1155Dispatcher { contract_address: token_address };

  erc1155.set_approval_for_all(operator: constants::BRIDGE(), approved: true);

  // set contract address back to bridge
  testing::set_contract_address(constants::BRIDGE());

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

  assert(kass.l1_kass_address() == constants::L1_KASS_ADDRESS(), 'Should be L1 kass addr');
}

// set_l1_kass_address

#[test]
#[available_gas(20000000)]
fn test_set_l1_kass_address() {
  let mut kass = setup();

  let new_l1_kass_address = constants::L1_KASS_ADDRESS_2();

  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
  assert(kass.l1_kass_address() == new_l1_kass_address, 'Should be new L1 kass addr');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_set_l1_kass_address_unauthorized() {
  let mut kass = setup();

  let new_l1_kass_address = constants::L1_KASS_ADDRESS_2();

  testing::set_caller_address(constants::OTHER());
  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_set_l1_kass_address_from_zero() {
  let mut kass = setup();

  let new_l1_kass_address = constants::L1_KASS_ADDRESS_2();

  testing::set_caller_address(constants::ZERO());
  kass.set_l1_kass_address(l1_kass_address_: new_l1_kass_address);
}

// upgrade

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_upgrade_unauthorized() {
  let mut kass = setup();

  testing::set_caller_address(constants::OTHER());
  kass.upgrade(new_implementation: 'new implementation'.try_into().unwrap());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_upgrade_from_zero() {
  let mut kass = setup();

  testing::set_caller_address(constants::ZERO());
  kass.upgrade(new_implementation: 'new implementation'.try_into().unwrap());
}

// ERC721 wrapper creation

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc721_creation() {
  let mut kass = setup();
  let kass_erc721 = setup_erc721_wrapper(ref kass: kass);

  assert(kass_erc721.name() == constants::L1_TOKEN_NAME, 'Invalid token name');
  assert(kass_erc721.symbol() == constants::L1_TOKEN_SYMBOL, 'Invalid token symbol');
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

  assert(kass_erc1155.uri(token_id: 0x1) == constants::L1_TOKEN_URI(), 'Invalid token uri');
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

  let native_token_address: felt252 = erc721.contract_address.into();
  let sender = constants::OWNER();
  let recipient = constants::L1_OTHER();
  let token_id = constants::TOKEN_ID;
  let amount: u256 = 0x1;
  let request_wrapper = true;

  kass.deposit_721(:native_token_address, :recipient, :token_id, :request_wrapper);

  assert_deposit_happened(:native_token_address, :recipient, :token_id, :amount, :request_wrapper);
}

// ERC1155 Wrapper request

#[test]
#[available_gas(20000000)]
fn test_wrapped_erc1155_request() {
  let mut kass = setup();
  let erc1155 = setup_erc1155();

  let native_token_address: felt252 = erc1155.contract_address.into();
  let sender = constants::OWNER();
  let recipient = constants::L1_OTHER();
  let token_id = constants::TOKEN_ID;
  let amount = constants::AMOUNT;
  let request_wrapper = true;

  kass.deposit_1155(:native_token_address, :recipient, :token_id, :amount, :request_wrapper);

  assert_deposit_happened(:native_token_address, :recipient, :token_id, :amount, :request_wrapper);
}

//
// Helpers
//

fn assert_deposit_happened(
  native_token_address: felt252,
  recipient: starknet::EthAddress,
  token_id: u256,
  amount: u256,
  request_wrapper: bool
) {
  // assert message has been sent to L1
  let kass_messaging_self = KassMessaging::unsafe_new_contract_state();

  let expected_payload = kass_messaging_self._compute_token_deposit_on_l1_message(
    :native_token_address,
    :recipient,
    :token_id,
    :amount,
    :request_wrapper
  );

  let (to_address, payload) = testing::pop_l2_to_l1_message(constants::BRIDGE()).unwrap();

  assert(to_address == constants::L1_KASS_ADDRESS().into(), 'msg wrong to_address');
  assert(payload == expected_payload.span(), 'msg wrong payload');

  // assert logs have been emitted
  if (request_wrapper) {
    let expected_log = KassBridge::Event::WrapperRequest(
      KassBridge::WrapperRequest { l2_token_address: native_token_address.try_into().unwrap() }
    );

    assert_eq(
      @testing::pop_log(constants::BRIDGE()).unwrap(),
      @expected_log,
      'invalid wrapper request log'
    );
  }

  let expected_log = KassBridge::Event::Deposit(
    KassBridge::Deposit {
      native_token_address,
      sender: constants::OWNER(),
      recipient,
      token_id,
      amount,
    }
  );

  assert_eq(
    @testing::pop_log(constants::BRIDGE()).unwrap(),
    @expected_log,
    'invalid deposit log'
  );
}

// Deposit ERC721

fn before_erc721_deposit(erc721: IERC721Dispatcher, depositor: starknet::ContractAddress, token_id: u256) {
  // assert deposit own token
  assert(erc721.owner_of(:token_id) == depositor, 'Invalid owner before');
}

fn after_native_erc721_deposit(erc721: IERC721Dispatcher, token_id: u256) {
  // assert deposit own token
  assert(erc721.owner_of(:token_id) == constants::BRIDGE(), 'Invalid owner after');
}

fn after_wrapped_erc721_deposit(erc721: KassERC721ABIDispatcher, token_id: u256) {
  // assert token has been burned
  assert(erc721.owner_of(:token_id) == constants::BRIDGE(), 'Invalid owner after');
}

    // // Deposit ERC721

    // function _beforeERC721Deposit(ERC721 token, address depositor, uint256 tokenId) private {
    //     // assert depositor owns token
    //     assertEq(token.ownerOf(tokenId), depositor);
    // }

    // function _afterERC721NativeDeposit(ERC721 token, uint256 tokenId) private {
    //     // assert bridge owns token
    //     assertEq(token.ownerOf(tokenId), address(_kassBridge));
    // }

    // function _afterWrappedERC721Deposit(ERC721 token, uint256 tokenId) private {
    //     // assert token has been burned
    //     vm.expectRevert("ERC721: invalid token ID");
    //     token.ownerOf(tokenId);
    // }

    // // Deposit ERC1155

    // function _beforeERC1155Deposit(ERC1155 token, address depositor, uint256 tokenId, uint256 amount) private {
    //     // assert depositor owns tokens
    //     assertEq(token.balanceOf(depositor, tokenId), amount);
    // }

    // function _afterERC1155NativeDeposit(
    //     ERC1155 token,
    //     address depositor,
    //     uint256 tokenId,
    //     uint256 amount,
    //     uint256 depositedAmount
    // ) private {
    //     // assert depositor and bridge own tokens
    //     assertEq(token.balanceOf(depositor, tokenId), amount - depositedAmount);
    //     assertEq(token.balanceOf(address(_kassBridge), tokenId), depositedAmount);
    // }

    // function _afterWrappedERC1155Deposit(
    //     ERC1155 token,
    //     address depositor,
    //     uint256 tokenId,
    //     uint256 amount,
    //     uint256 depositedAmount
    // ) private {
    //     // assert depositor and bridge own tokens
    //     assertEq(token.balanceOf(depositor, tokenId), amount - depositedAmount);
    // }
