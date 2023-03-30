#[contract]
mod Kass {

    // USES

    use starknet::ContractAddressIntoFelt252;
    use array::ArrayTrait;
    use integer::Felt252IntoU256;
    use integer::U128IntoFelt252;
    use traits::Into;

    use kass::utils::ArrayTConcatTrait;
    use kass::utils::LegacyHashClassHash;
    use kass::interfaces::IERC1155::IERC1155Dispatcher;
    use kass::interfaces::IERC1155::IERC1155DispatcherTrait;

    use kass::libraries::Upgradeable;
    use kass::libraries::Ownable;

    // CONSTANTS

    use kass::constants::REQUEST_L1_INSTANCE;
    use kass::constants::TRANSFER_FROM_STARKNET;
    use kass::constants::IERC1155_ACCEPTED_ID;

    // STORAGE

    struct Storage {
        // L1 Address of the Kass contract
        _l1KassAddress: felt252,

        // (implementation address => initialization status) mapping
        _initializedClassHashes: LegacyMap<starknet::ClassHash, bool>,
    }

    // MODIFIERS

    fn _initializer() {
        let classHash = starknet::class_hash_const::<0>(); // TODO: get current class hash

        assert(!_isInitialized(classHash), 'Already initialized');

        _setInitialized(classHash);
    }

    // INIT

    #[constructor]
    fn constructor() { }

    #[external]
    fn initialize(l1KassAddress_: felt252) {
        // modifiers
        _initializer();

        // body
        _l1KassAddress::write(l1KassAddress_);

        let caller = starknet::get_caller_address();
        Ownable::transferOwnership(caller);
    }

    // UPGRADE

    #[external]
    fn upgradeToAndCall(newClassHash: starknet::ClassHash, call: Upgradeable::Call) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        Upgradeable::upgradeToAndCall(newClassHash, call);
    }

    // GETTERS

    #[view]
    fn l1KassAddress() -> felt252 {
        _l1KassAddress::read()
    }

    #[view]
    fn owner() {
        Ownable::getOwner();
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: felt252) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        _l1KassAddress::write(l1KassAddress_);
    }

    // BUSINESS LOGIC

    #[external]
    fn requestL1Instance(l2TokenAddress: starknet::ContractAddress) {
        // get contract uri
        let uri = IERC1155Dispatcher { contract_address: l2TokenAddress }.uri(0.into());

        // load payload
        let mut payload = ArrayTrait::<felt252>::new();

        payload.append(REQUEST_L1_INSTANCE);
        payload.append(l2TokenAddress.into());

        payload.concat(@uri);

        // TODO send message syscall
    }

    #[external]
    fn deposit(l2TokenAddress: starknet::ContractAddress, tokenId: u256, amount: u256, l1Recipient: felt252) {
        let caller = starknet::get_caller_address();
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
            caller,
            contractAddress,
            tokenId,
            amount,
            ArrayTrait::<felt252>::new()
        );

        // load payload
        let mut payload = ArrayTrait::<felt252>::new();

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
        operator: starknet::ContractAddress,
        from: starknet::ContractAddress,
        id: u256,
        value: u256,
        data: Array<felt252>
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
    fn withdraw(l2Recipient: starknet::ContractAddress, l2TokenAddress: starknet::ContractAddress, tokenId: u256, amount: u256) {
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
            contractAddress,
            l2Recipient,
            tokenId,
            amount,
            ArrayTrait::<felt252>::new()
        );
    }

    // INTERNALS

    fn _isInitialized(classHash: starknet::ClassHash) -> bool {
        _initializedClassHashes::read(classHash)
    }

    fn _setInitialized(classHash: starknet::ClassHash) {
        _initializedClassHashes::write(classHash, true);
    }
}
