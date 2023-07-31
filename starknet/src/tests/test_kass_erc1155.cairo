use starknet::testing;

// locals
use kass::factory::erc1155::{ KassERC1155, KassERC1155ABI };

use super::constants;

use super::utils;

// Dispatchers
use kass::factory::erc1155::{ KassERC1155ABIDispatcher, KassERC1155ABIDispatcherTrait };

//
// Setup
//

fn setup() -> KassERC1155ABIDispatcher {
  let calldata = array![];

  testing::set_contract_address(constants::BRIDGE());

  let token_address = utils::deploy(KassERC1155::TEST_CLASS_HASH, calldata);

  let kass_erc1155 = KassERC1155ABIDispatcher { contract_address: token_address };
  kass_erc1155.initialize(uri_: constants::L1_TOKEN_URI(), bridge_: constants::BRIDGE());

  kass_erc1155
}

//
// Tests
//

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc1155.upgrade(new_implementation: constants::KASS_ERC721_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_from_zero() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc1155.upgrade(new_implementation: constants::KASS_ERC721_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Kass1155: Already initialized', 'ENTRYPOINT_FAILED',))]
fn test_double_intialize() {
  let mut kass_erc1155 = setup();

  kass_erc1155.initialize(uri_: constants::L1_TOKEN_URI(), bridge_: constants::BRIDGE());
}

// permissioned methods

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_mint_unauthorized() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc1155.permissioned_mint(to: constants::OTHER(), id: constants::TOKEN_ID, amount: constants::AMOUNT);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_mint_from_zero() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc1155.permissioned_mint(to: constants::OTHER(), id: constants::TOKEN_ID, amount: constants::AMOUNT);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_burn_unauthorized() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc1155.permissioned_burn(from: constants::OTHER(), id: constants::TOKEN_ID, amount: constants::AMOUNT);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_burn_from_zero() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc1155.permissioned_burn(from: constants::OTHER(), id: constants::TOKEN_ID, amount: constants::AMOUNT);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_upgrade_unauthorized() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc1155.permissioned_upgrade(new_implementation: constants::KASS_ERC721_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_upgrade_from_zero() {
  let mut kass_erc1155 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc1155.permissioned_upgrade(new_implementation: constants::KASS_ERC721_CLASS_HASH());
}
