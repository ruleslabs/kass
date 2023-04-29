#[abi]
trait IMockUpgradedContract {
    fn foo() -> felt252;
}

#[contract]
mod MockUpgradedContract {

    struct Storage {
        _foo: felt252
    }

    #[external]
    fn initialize(foo_: felt252) {
        _foo::write(foo_);
    }

    #[view]
    fn foo() -> felt252 {
        _foo::read()
    }
}
