mod Ownable {

    // USES

    use starknet::ContractAddressIntoFelt;
    use starknet::FeltTryIntoContractAddress;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;

    // MODIFIERS

    fn _onlyOwner() {
        let owner = getOwner();
        let caller = starknet::get_caller_address();

        assert(owner.into() == caller.into(), 'Caller is not the owner');
    }

    // GETTERS

    fn getOwner() -> ContractAddress {
        _owner::read()
    }

    // SETTERS

    fn renounceOwnership() {
        _owner::write(0x0.try_into().unwrap());
    }

    fn transferOwnership(owner: ContractAddress) {
        _owner::write(owner);
    }

    // STORAGE

    mod _owner {
        use starknet::SyscallResultTrait;

        fn read() -> ContractAddress {
            starknet::StorageAccess::<ContractAddress>::read(0, address()).unwrap_syscall()
        }

        fn write(value: ContractAddress) {
            starknet::StorageAccess::<ContractAddress>::write(0, address(), value).unwrap_syscall()
        }

        fn address() -> starknet::StorageBaseAddress {
            // "Ownable::owner" selector
            starknet::storage_base_address_const::<0x3db50198d2471ec1c5b126cf42805578fd6ddbfbfe01821f502e48da5e2e2f>()
        }
    }
}
