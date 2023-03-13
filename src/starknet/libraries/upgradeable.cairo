mod Upgradeable {

    // USES

    use starknet::SyscallResultTrait;
    use starknet::ContractAddressIntoFelt;
    use starknet::FeltTryIntoContractAddress;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;

    use super::Call;
    use super::CallSerde;

    // EVENTS

    #[event]
    fn Upgraded(implementation: ContractAddress) {}

    // MODIFIERS

    fn _onlyProxy() {
        let self = starknet::StorageAccess::<ContractAddress>::read(0, _selfStorageBaseAddress()).unwrap_syscall();
        let contractAddress = starknet::get_contract_address();

        assert(contractAddress.into() != self.into(), 'Not called through delegatecall');
        assert(getImplementation().into() == self.into(), 'Not called through active proxy');
    }

    // CONSTRUCTOR

    fn constructor() {
        let contractAddress = starknet::get_contract_address();

        starknet::StorageAccess::<ContractAddress>::write(
            0,
            _selfStorageBaseAddress(),
            contractAddress
        ).unwrap_syscall();
    }

    // GETTERS

    fn getImplementation() -> ContractAddress {
        starknet::StorageAccess::<ContractAddress>::read(0, _implementationStorageBaseAddress()).unwrap_syscall()
    }

    // BUSINESS LOGIC

    fn upgradeTo(newImplementation: ContractAddress) {
        // modifiers
        _onlyProxy();

        // body
        _upgradeTo(newImplementation);
    }

    fn upgradeToAndCall(newImplementation: ContractAddress, mut call: Call) {
        // modifiers
        _onlyProxy();

        // body
        _upgradeTo(newImplementation);

        let Call{ selector, calldata } = call;

        starknet::call_contract_syscall(
            address: newImplementation, entry_point_selector: selector, :calldata
        ).unwrap_syscall();
    }

    // INTERNALS

    fn _upgradeTo(newImplementation: ContractAddress) {
        starknet::StorageAccess::<ContractAddress>::write(
            0,
            _selfStorageBaseAddress(),
            newImplementation
        ).unwrap_syscall();

        // emit event
        Upgraded(newImplementation);
    }

    fn _implementationStorageBaseAddress() -> starknet::StorageBaseAddress {
        // "Upgradeable::implementation" selector
        starknet::storage_base_address_const::<0x2189f356cbba04c9b5b5431158c2dad8b31d4881bb327621ed354994933c758>()
    }

    fn _selfStorageBaseAddress() -> starknet::StorageBaseAddress {
        // "Upgradeable::self" selector
        starknet::storage_base_address_const::<0xb7d0a441a2b8912103b9d4a723639b43c81d8c89a77e2b78a05c591d186e56>()
    }
}

use serde::Serde;

struct Call {
    selector: felt,
    calldata: Array<felt>
}

impl CallDrop of Drop::<Call>;

impl CallSerde of Serde::<Call> {
    fn serialize(ref output: Array<felt>, input: Call) {
        let Call{ selector, calldata } = input;
        Serde::serialize(ref output, selector);
        Serde::serialize(ref output, calldata);
    }

    fn deserialize(ref serialized: Span<felt>) -> Option<Call> {
        let selector = Serde::<felt>::deserialize(ref serialized)?;
        let calldata = Serde::<Array::<felt>>::deserialize(ref serialized)?;
        Option::Some(Call { selector, calldata })
    }
}
