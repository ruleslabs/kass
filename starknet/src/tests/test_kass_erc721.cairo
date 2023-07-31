use starknet::testing;

// locals
use kass::factory::erc721::{ KassERC721, KassERC721ABI };

use super::constants;

use super::utils;

// Dispatchers
use kass::factory::erc721::{ KassERC721ABIDispatcher, KassERC721ABIDispatcherTrait };

//
// Setup
//

fn setup() -> KassERC721ABIDispatcher {
  let calldata = array![];

  testing::set_contract_address(constants::BRIDGE());

  let token_address = utils::deploy(KassERC721::TEST_CLASS_HASH, calldata);

  let kass_erc721 = KassERC721ABIDispatcher { contract_address: token_address };
  kass_erc721.initialize(
    name_: constants::L1_TOKEN_NAME,
    symbol_: constants::L1_TOKEN_SYMBOL,
    bridge_: constants::BRIDGE()
  );

  kass_erc721
}

//
// Tests
//

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc721.upgrade(new_implementation: constants::KASS_ERC1155_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_from_zero() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc721.upgrade(new_implementation: constants::KASS_ERC1155_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Kass721: Already initialized', 'ENTRYPOINT_FAILED',))]
fn test_double_intialize() {
  let mut kass_erc721 = setup();

  kass_erc721.initialize(
    name_: constants::L1_TOKEN_NAME,
    symbol_: constants::L1_TOKEN_SYMBOL,
    bridge_: constants::BRIDGE()
  );
}

// permissioned methods

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_mint_unauthorized() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc721.permissioned_mint(to: constants::OTHER(), token_id: constants::TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_mint_from_zero() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc721.permissioned_mint(to: constants::OTHER(), token_id: constants::TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_burn_unauthorized() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc721.permissioned_burn(token_id: constants::TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_burn_from_zero() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc721.permissioned_burn(token_id: constants::TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the bridge', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_upgrade_unauthorized() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::OTHER());

  kass_erc721.permissioned_upgrade(new_implementation: constants::KASS_ERC1155_CLASS_HASH());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED',))]
fn test_permissioned_upgrade_from_zero() {
  let mut kass_erc721 = setup();

  testing::set_contract_address(constants::ZERO());

  kass_erc721.permissioned_upgrade(new_implementation: constants::KASS_ERC1155_CLASS_HASH());
}
