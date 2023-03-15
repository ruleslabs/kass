use hash::LegacyHash;
use traits::Into;
use starknet::ClassHashIntoFelt252;

impl LegacyHashClassHash of LegacyHash::<starknet::ClassHash> {
    fn hash(state: felt252, value: starknet::ClassHash) -> felt252 {
        LegacyHash::<felt252>::hash(state, value.into())
    }
}
