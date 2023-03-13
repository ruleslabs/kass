#[contract]
mod Kass {

    // USES

    use starknet::ContractAddressIntoFelt;
    use array::ArrayTrait;
    use integer::FeltIntoU256;
    use integer::U128IntoFelt;
    use traits::Into;

    use kass::utils::concat::ArrayTConcatTrait;
    use kass::interfaces::IERC1155::IERC1155Dispatcher;
    use kass::interfaces::IERC1155::IERC1155DispatcherTrait;

    use kass::libraries::Ownable;
    use kass::libraries::Upgradeable;

    // CONSTANTS

    use kass::constants::REQUEST_L1_INSTANCE;
    use kass::constants::TRANSFER_FROM_STARKNET;
    use kass::constants::IERC1155_ACCEPTED_ID;

    // STORAGE

    struct Storage {
        // L1 Address of the Kass contract
        _l1KassAddress: felt,

        // (implementation address => initialization status) mapping
        _initializedImplementations: LegacyMap<ContractAddress, bool>,
    }

    // MODIFIERS

    fn _initializer() {
        let implementation = Upgradeable::getImplementation();

        assert(!_isInitialized(implementation), 'Already initialized');

        _setInitialized(implementation);
    }

    // INIT

    #[constructor]
    fn constructor() {
        Upgradeable::constructor();
    }

    #[external]
    fn initialize(l1KassAddress_: felt) {
        // modifiers
        _initializer();

        // body
        _l1KassAddress::write(l1KassAddress_);

        let caller = starknet::get_caller_address();
        Ownable::transferOwnership(caller);
    }

    // UPGRADE

    #[external]
    fn upgradeToAndCall(newImplementation: ContractAddress, call: Upgradeable::Call) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        Upgradeable::upgradeToAndCall(newImplementation, call);
    }

    // GETTERS

    #[view]
    fn l1KassAddress() -> felt {
        _l1KassAddress::read()
    }

    #[view]
    fn owner() {
        Ownable::getOwner();
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: felt) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        _l1KassAddress::write(l1KassAddress_);
    }

    // BUSINESS LOGIC

    #[external]
    fn requestL1Instance(l2TokenAddress: ContractAddress) {
        // get contract uri
        let uri = IERC1155Dispatcher { contract_address: l2TokenAddress }.uri(0.into());

        // load payload
        let mut payload = ArrayTrait::<felt>::new();

        payload.append(REQUEST_L1_INSTANCE);
        payload.append(l2TokenAddress.into());

        payload.concat(@uri);

        // TODO send message syscall
    }

    #[external]
    fn deposit(l2TokenAddress: ContractAddress, tokenId: u256, amount: u256, l1Recipient: felt) {
        let caller = starknet::get_caller_address();
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
            caller,
            contractAddress,
            tokenId,
            amount,
            ArrayTrait::<felt>::new()
        );

        // load payload
        let mut payload = ArrayTrait::<felt>::new();

        payload.append(TRANSFER_FROM_STARKNET);
        payload.append(l1Recipient);
        payload.append(l2TokenAddress.into());

        payload.append(tokenId.low.into());
        payload.append(tokenId.high.into());

        payload.append(amount.low.into());
        payload.append(amount.high.into());

        // TODO send message syscall
    }

    #[external]
    fn onERC1155Received(
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Array<felt>
    ) -> u32 {
        let contractAddress = starknet::get_contract_address();

        // validate transfer only if it's executed in the context of a deposit
        if (contractAddress.into() == operator.into()) {
            return IERC1155_ACCEPTED_ID;
        }

        0_u32
    }

    // HANDLERS

    // withdraw l1 handler
    #[l1_handler]
    fn withdraw(l2Recipient: ContractAddress, l2TokenAddress: ContractAddress, tokenId: u256, amount: u256) {
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
            contractAddress,
            l2Recipient,
            tokenId,
            amount,
            ArrayTrait::<felt>::new()
        );
    }

    // INTERNALS

    fn _isInitialized(implementation: ContractAddress) -> bool {
        _initializedImplementations::read(implementation)
    }

    fn _setInitialized(implementation: ContractAddress) {
        _initializedImplementations::write(implementation, true);
    }
}
