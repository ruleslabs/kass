const L1_KASS_ADDRESS: felt252 = 0x64590f95eabb6091373c9dbd1366e7f757d6db43;
const INITIALIZE_SELECTOR: felt252 = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;

mod KassTestBase {

    use array::ArrayTrait;
    use traits::TryInto;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use option::OptionTrait;
    use starknet::syscalls::deploy_syscall;
    use core::result::ResultTrait;

    use kass::Kass;
    use kass::IKassDispatcher;
    use kass::IKassDispatcherTrait;

    fn deployKass() -> IKassDispatcher {
        let (kass_address, _) = deploy_syscall(
            Kass::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
        ).unwrap();

        return IKassDispatcher { contract_address: kass_address };
    }
}
