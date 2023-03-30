#[contract]
mod Ownable {

    // STORAGE

    struct Storage {
        owner: starknet::ContractAddress,
    }

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
        owner::read()
    }

    // SETTERS

    fn renounceOwnership() {
        owner::write(starknet::contract_address_const::<0>());
    }

    fn transferOwnership(owner: starknet::ContractAddress) {
        owner::write(owner);
    }
}
