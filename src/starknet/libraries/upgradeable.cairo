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
        let self = _self::read();
        let contractAddress = starknet::get_contract_address();

        assert(contractAddress.into() != self.into(), 'Not called through delegatecall');
        assert(getImplementation().into() == self.into(), 'Not called through active proxy');
    }

    // CONSTRUCTOR

    fn constructor() {
        let contractAddress = starknet::get_contract_address();
        _self::write(contractAddress);
    }

    // GETTERS

    fn getImplementation() -> ContractAddress {
        _implementation::read()
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
        _implementation::write(newImplementation);

        // emit event
        Upgraded(newImplementation);
    }

    // STORAGE

    mod _implementation {
        use starknet::SyscallResultTrait;

        fn read() -> ContractAddress {
            starknet::StorageAccess::<ContractAddress>::read(0, address()).unwrap_syscall()
        }

        fn write(value: ContractAddress) {
            starknet::StorageAccess::<ContractAddress>::write(0, address(), value).unwrap_syscall()
        }

        fn address() -> starknet::StorageBaseAddress {
            // "Upgradeable::implementation" selector
            starknet::storage_base_address_const::<0x2189f356cbba04c9b5b5431158c2dad8b31d4881bb327621ed354994933c758>()
        }
    }

    mod _self {
        use starknet::SyscallResultTrait;

        fn read() -> ContractAddress {
            starknet::StorageAccess::<ContractAddress>::read(0, address()).unwrap_syscall()
        }

        fn write(value: ContractAddress) {
            starknet::StorageAccess::<ContractAddress>::write(0, address(), value).unwrap_syscall()
        }

        fn address() -> starknet::StorageBaseAddress {
            // "Upgradeable::self" selector
            starknet::storage_base_address_const::<0xb7d0a441a2b8912103b9d4a723639b43c81d8c89a77e2b78a05c591d186e56>()
        }
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
