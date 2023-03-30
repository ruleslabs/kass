mod Upgradeable {

    // USES

    use starknet::SyscallResultTrait;

    use super::Call;
    use super::CallSerde;

    // EVENTS

    #[event]
    fn Upgraded(classHash: starknet::ClassHash) {}

    // BUSINESS LOGIC

    fn upgradeTo(newClassHash: starknet::ClassHash) {
        _upgradeTo(newClassHash);
    }

    fn upgradeToAndCall(newClassHash: starknet::ClassHash, mut call: Call) {
        _upgradeTo(newClassHash);

        let Call{ selector, calldata } = call;

        starknet::syscalls::library_call_syscall(
            class_hash: newClassHash,
            function_selector: selector,
            calldata: array::ArrayTrait::span(@calldata)
        ).unwrap_syscall();
    }

    // INTERNALS

    fn _upgradeTo(newClassHash: starknet::ClassHash) {
        starknet::syscalls::replace_class_syscall(newClassHash);

        // emit event
        Upgraded(newClassHash);
    }
}

use serde::Serde;

struct Call {
    selector: felt252,
    calldata: Array<felt252>
}

impl CallDrop of Drop::<Call>;

impl CallSerde of Serde::<Call> {
    fn serialize(ref output: Array<felt252>, input: Call) {
        let Call{ selector, calldata } = input;
        Serde::serialize(ref output, selector);
        Serde::serialize(ref output, calldata);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<Call> {
        let selector = Serde::<felt252>::deserialize(ref serialized)?;
        let calldata = Serde::<Array::<felt252>>::deserialize(ref serialized)?;
        Option::Some(Call { selector, calldata })
    }
}
