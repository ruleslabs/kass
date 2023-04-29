use array::ArrayTrait;
use traits::Into;
use traits::TryInto;
use starknet::class_hash::Felt252TryIntoClassHash;
use option::OptionTrait;
use starknet::syscalls::deploy_syscall;
use core::result::ResultTrait;
use starknet::Felt252TryIntoEthAddress;

use kass::Kass;
use kass::IKassDispatcher;
use kass::IKassDispatcherTrait;

use kass::libraries::Upgradeable;

use kass::tests::L1_KASS_ADDRESS;
use kass::tests::INITIALIZE_SELECTOR;
use kass::tests::KassTestBase;

// MOCKS

use kass::tests::mocks::MockUpgradedContract;
use kass::tests::mocks::IMockUpgradedContractDispatcher;
use kass::tests::mocks::IMockUpgradedContractDispatcherTrait;

// TESTS

#[test]
#[available_gas(2000000)]
fn test_Initialize() {
    let Kass = KassTestBase::deployKass();
    Kass::initialize(L1_KASS_ADDRESS.try_into().unwrap());

    assert(Kass::l1KassAddress().into() == L1_KASS_ADDRESS, 'Bad L1 kass addr after init');
}

#[test]
#[available_gas(2000000)]
fn test_UpdateL1KassAddress() {
    let Kass = KassTestBase::deployKass();
    Kass::initialize(L1_KASS_ADDRESS.try_into().unwrap());

    Kass::setL1KassAddress(0xdead.try_into().unwrap());

    assert(Kass::l1KassAddress().into() == 0xdead, 'Bad L1 kass addr after update');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_CannotUpdateL1KassAddressIfNotOwner() {
    let owner = starknet::contract_address_const::<1>();
    let rando1 = starknet::contract_address_const::<2>();

    // deploy as owner
    let Kass = KassTestBase::deployKass();
    Kass::initialize(L1_KASS_ADDRESS.try_into().unwrap());
    Kass::setL1KassAddress(0x4242.try_into().unwrap());

    // calls as random
    starknet::testing::set_caller_address(rando1);
    Kass::setL1KassAddress(0xdead.try_into().unwrap());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Already initialized', ))]
fn test_CannotInitializeTwice() {
    let Kass = KassTestBase::deployKass();
    Kass::initialize(L1_KASS_ADDRESS.try_into().unwrap());
    Kass::initialize(0xdead.try_into().unwrap());
}

// #[test]
// #[available_gas(2000000)]
// fn testUpgradeImplementation() {
    // let Kass = KassTestBase::deployKass();

//     // upgrade
//     let mut calldata = ArrayTrait::<felt252>::new();
//     calldata.append(0x42);

//     Kass::upgradeToAndCall(
//         MockUpgradedContract::TEST_CLASS_HASH.try_into().unwrap(),
//         Upgradeable::Call { selector: INITIALIZE_SELECTOR, calldata: calldata }
//     );

//     let MockUpgradedContract = IMockUpgradedContractDispatcher { contract_address: kass_address };

//     assert(MockUpgradedContract.foo() == 0x42, '');
// }

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_CannotUpgradeImplementationIfNotOwner() {
    let owner = starknet::contract_address_const::<'owner'>();
    let rando1 = starknet::contract_address_const::<'rando1'>();

    // calls as owner
    starknet::testing::set_caller_address(owner);
    let Kass = KassTestBase::deployKass();

    // upgrade as random
    starknet::testing::set_caller_address(rando1);
    Kass::upgradeToAndCall(
        starknet::class_hash_const::<0xdead>(),
        Upgradeable::Call { selector: INITIALIZE_SELECTOR, calldata: ArrayTrait::<felt252>::new() }
    );
}

// #[test]
// #[available_gas(2000000)]
// #[should_panic(expected: ('ENTRYPOINT_FAILED', ))]
// fn testCannotUpgradeToInvalidImplementation() {
    // let Kass = KassTestBase::deployKass();

//     // upgrade
//     Kass::upgradeToAndCall(
//         starknet::class_hash_const::<0xdead>(),
//         Upgradeable::Call { selector: INITIALIZE_SELECTOR, calldata: ArrayTrait::<felt252>::new() }
//     );
// }
