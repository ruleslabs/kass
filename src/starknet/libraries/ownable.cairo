mod Ownable {

    // USES

    use starknet::SyscallResultTrait;
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
        starknet::StorageAccess::<ContractAddress>::read(0, _ownerStorageBaseAddress()).unwrap_syscall()
    }

    // SETTERS

    fn renounceOwnership() {
        starknet::StorageAccess::<ContractAddress>::write(
            0,
            _ownerStorageBaseAddress(),
            0x0.try_into().unwrap()
        ).unwrap_syscall();
    }

    fn transferOwnership(owner: ContractAddress) {
        starknet::StorageAccess::<ContractAddress>::write(0, _ownerStorageBaseAddress(), owner).unwrap_syscall();
    }

    // INTERNALS

    fn _ownerStorageBaseAddress() -> starknet::StorageBaseAddress {
        // "Ownable::owner" selector
        starknet::storage_base_address_const::<0x3db50198d2471ec1c5b126cf42805578fd6ddbfbfe01821f502e48da5e2e2f>()
    }
}
