use traits::{ Into, TryInto };
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;

// locals
use kass::bridge::interface::IKassTokenDeployer;

use kass::bridge::token_deployer::KassTokenDeployer;
use kass::bridge::token_deployer::KassTokenDeployer::{ ContractState as KassTokenDeployerContractState };

use kass::token::erc721::KassERC721;
use kass::token::erc1155::KassERC1155;

fn KASS_ERC721_CLASS_HASH() -> starknet::ClassHash {
  KassERC721::TEST_CLASS_HASH.try_into().unwrap()
}

fn KASS_ERC1155_CLASS_HASH() -> starknet::ClassHash {
  KassERC1155::TEST_CLASS_HASH.try_into().unwrap()
}

fn setup() -> KassTokenDeployerContractState {
  let kass_token_deployer = KassTokenDeployer::unsafe_new_contract_state();

  kass_token_deployer
}

#[test]
#[available_gas(20000000)]
fn test_set_deployer_class_hashes() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
    erc721_implementation_address_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC1155_CLASS_HASH(),
  );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Invalid ERC721 implementation',))]
fn test_set_deployer_class_hashes_invalid_erc721() {
  let mut kass_token_deployer = setup();

  kass_token_deployer.set_deployer_class_hashes(
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
    erc721_implementation_address_: KASS_ERC721_CLASS_HASH(),
    erc1155_implementation_address_: KASS_ERC721_CLASS_HASH(),
  );
}
