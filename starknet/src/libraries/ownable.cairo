mod Ownable {

    // USES

    use starknet::ContractAddressIntoFelt252;
    use traits::Into;

    // MODIFIERS

    fn _onlyOwner() {
        let owner = getOwner();
        let caller = starknet::get_caller_address();

        assert(owner.into() == caller.into(), 'Caller is not the owner');
    }

    // GETTERS

    fn getOwner() -> starknet::ContractAddress {
        _owner::read()
    }

    // SETTERS

    fn renounceOwnership() {
        _owner::write(starknet::contract_address_const::<0>());
    }

    fn transferOwnership(owner: starknet::ContractAddress) {
        _owner::write(owner);
    }

    // STORAGE

    mod _owner {
        use starknet::SyscallResultTrait;

        fn read() -> starknet::ContractAddress {
            starknet::StorageAccess::<starknet::ContractAddress>::read(0, address()).unwrap_syscall()
        }

        fn write(value: starknet::ContractAddress) {
            starknet::StorageAccess::<starknet::ContractAddress>::write(0, address(), value).unwrap_syscall()
        }

        fn address() -> starknet::StorageBaseAddress {
            // "Ownable::owner" selector
            starknet::storage_base_address_const::<0x3db50198d2471ec1c5b126cf42805578fd6ddbfbfe01821f502e48da5e2e2f>()
        }
    }
}
