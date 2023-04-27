use array::ArrayTrait;
use traits::Into;

use kass::Kass;

use kass::libraries::Upgradeable;

use kass::utils::EthAddressTrait;
use kass::utils::eth_address::EthAddressIntoFelt252;

use kass::tests::L1_KASS_ADDRESS;
use kass::tests::INITIALIZE_SELECTOR;

#[test]
#[available_gas(2000000)]
fn test_Initialize() {
    Kass::constructor();
    Kass::initialize(EthAddressTrait::new(L1_KASS_ADDRESS));

    assert(Kass::l1KassAddress().into() == L1_KASS_ADDRESS, 'Bad L1 kass addr after init');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Already initialized', ))]
fn test_CannotInitializeTwice() {
    Kass::constructor();
    Kass::initialize(EthAddressTrait::new(L1_KASS_ADDRESS));
    Kass::initialize(EthAddressTrait::new(0xdead));
}

#[test]
#[available_gas(2000000)]
fn test_SetL1KassAddress() {
    Kass::constructor();
    Kass::initialize(EthAddressTrait::new(L1_KASS_ADDRESS));

    Kass::setL1KassAddress(EthAddressTrait::new(0xdead));

    assert(Kass::l1KassAddress().into() == 0xdead, 'Bad L1 kass addr after update');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Caller is not the owner', ))]
fn test_CannotSetL1KassAddressIfNotOwner() {
    let owner = starknet::contract_address_const::<1>();
    let rando1 = starknet::contract_address_const::<2>();

    // deploy as owner
    starknet::testing::set_caller_address(owner);
    Kass::constructor();
    Kass::initialize(EthAddressTrait::new(L1_KASS_ADDRESS));
    Kass::setL1KassAddress(EthAddressTrait::new(0x4242));

    // calls as random
    starknet::testing::set_caller_address(rando1);
    Kass::setL1KassAddress(EthAddressTrait::new(0xdead));
}

// #[test]
// #[available_gas(2000000)]
// fn testUpgradeImplementation() {

// }

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Caller is not the owner', ))]
fn test_CannotUpgradeImplementationIfNotOwner() {
    let owner = starknet::contract_address_const::<1>();
    let rando1 = starknet::contract_address_const::<2>();

    // calls as owner
    starknet::testing::set_caller_address(owner);
    Kass::constructor();
    Kass::initialize(EthAddressTrait::new(L1_KASS_ADDRESS));

    // upgrade as random
    starknet::testing::set_caller_address(rando1);
    Kass::upgradeToAndCall(
        starknet::class_hash_const::<0xdead>(),
        Upgradeable::Call { selector: INITIALIZE_SELECTOR, calldata: ArrayTrait::<felt252>::new() }
    );
}

// #[test]
// #[available_gas(2000000)]
// fn testCannotUpgradeImplementationIfNotOwner() {

// }
