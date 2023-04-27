#[contract]
mod Kass {

    // USES

    use starknet::ContractAddressIntoFelt252;
    use array::ArrayTrait;
    use integer::Felt252IntoU256;
    use integer::U128IntoFelt252;
    use traits::Into;
    use zeroable::Zeroable;

    use kass::utils::ArrayTConcatTrait;
    use kass::utils::LegacyHashClassHash;
    use kass::utils::EthAddress;
    use kass::utils::EthAddressTrait;
    use kass::utils::eth_address::EthAddressZeroable;
    use kass::utils::eth_address::EthAddressIntoFelt252;
    use kass::utils::TokenStandard;

    use kass::TokenDeployer;
    use kass::KassMessagingPayloads;

    use kass::interfaces::IERC721::IERC721Dispatcher;
    use kass::interfaces::IERC721::IERC721DispatcherTrait;

    use kass::interfaces::IERC1155::IERC1155Dispatcher;
    use kass::interfaces::IERC1155::IERC1155DispatcherTrait;

    use kass::libraries::Upgradeable;
    use kass::libraries::Ownable;

    // CONSTANTS

    use kass::constants::CONTRACT_IDENTITY;
    use kass::constants::CONTRACT_VERSION;

    use kass::constants::IERC1155_ACCEPTED_ID;

    // STORAGE

    struct Storage {
        // L1 Address of the Kass contract
        _l1KassAddress: EthAddress,

        // (implementation address => initialization status) mapping
        _initializedClassHashes: LegacyMap<starknet::ClassHash, bool>,
    }

    // MODIFIERS

    fn _initializer() {
        let classHash = starknet::class_hash_const::<0>(); // TODO: get current class hash

        assert(!_isInitialized(classHash), 'Already initialized');

        _setInitialized(classHash);
    }

    fn _l1_handler(from_address: EthAddress) {
        assert(from_address == l1KassAddress(), 'EXPECTED_FROM_L1_KASS_ONLY');
    }

    // HEADER

    #[view]
    fn get_version() -> felt252 {
        CONTRACT_VERSION
    }

    #[view]
    fn get_identity() -> felt252 {
        CONTRACT_IDENTITY
    }

    // INIT

    #[constructor]
    fn constructor() { }

    #[external]
    fn initialize(l1KassAddress_: EthAddress) {
        // modifiers
        _initializer();

        // body
        _l1KassAddress::write(l1KassAddress_);

        TokenDeployer::setDeployerClassHashes();

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
    fn l1KassAddress() -> EthAddress {
        _l1KassAddress::read()
    }

    #[view]
    fn owner() {
        Ownable::getOwner();
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: EthAddress) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        assert(l1KassAddress_.is_non_zero(), 'ZERO_L1_KASS_ADDRESS');

        _l1KassAddress::write(l1KassAddress_);
    }

    // TODO: init status support

    // INSTANCE CREATION

    #[l1_handler]
    fn createL2Wrapper721(
        from_address: felt252,
        l1TokenAddress: EthAddress,
        data: Array<felt252>
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body

        // deploy Kass ERC 721
        TokenDeployer::deployKassERC721(l1TokenAddress.into(), data.span());
    }

    #[l1_handler]
    fn createL2Wrapper1155(
        from_address: felt252,
        l1TokenAddress: EthAddress,
        data: Array<felt252>
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body

        // deploy Kass ERC 1155
        TokenDeployer::deployKassERC1155(l1TokenAddress.into(), data.span());
    }

    // INSTANCE REQUEST

    fn _requestL1Wrapper(
        l2TokenAddress: starknet::ContractAddress,
        ref data: Array<felt252>,
        tokenStandard: TokenStandard
    ) {
        // load payload
        let message_payload = KassMessagingPayloads::computeL1WrapperRequestMessage(
            l2TokenAddress,
            ref data,
            tokenStandard
        );

        // send instance request to L1
        starknet::syscalls::send_message_to_l1_syscall(
            to_address: l1KassAddress().into(),
            payload: message_payload.span()
        );
    }

    #[external]
    fn requestL1Wrapper721(l2TokenAddress: starknet::ContractAddress) {
        // get contract name and symbol
        let mut data: Array<felt252> = ArrayTrait::new();

        data.append(IERC721Dispatcher { contract_address: l2TokenAddress }.name());
        data.append(IERC721Dispatcher { contract_address: l2TokenAddress }.symbol());

        _requestL1Wrapper(l2TokenAddress, ref data, TokenStandard::ERC721(()));
    }

    #[external]
    fn requestL1Wrapper1155(l2TokenAddress: starknet::ContractAddress) {
        // get contract uri
        let mut uri = IERC1155Dispatcher { contract_address: l2TokenAddress }.uri(0.into());

        _requestL1Wrapper(l2TokenAddress, ref uri, TokenStandard::ERC1155(()));
    }

    // DEPOSIT

    fn _deposit(
        l2TokenAddress: starknet::ContractAddress,
        l1Recipient: EthAddress,
        tokenId: u256,
        amount: u256,
        tokenStandard: TokenStandard
    ) {
        let caller = starknet::get_caller_address();
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        match tokenStandard {
            TokenStandard::ERC721(_) => {
                IERC721Dispatcher { contract_address: l2TokenAddress }.transferFrom(
                    caller,
                    contractAddress,
                    tokenId
                );
            },
            TokenStandard::ERC1155(_) => {
                IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
                    caller,
                    contractAddress,
                    tokenId,
                    amount,
                    ArrayTrait::<felt252>::new()
                );
            }
        }

        // load payload
        let mut message_payload = KassMessagingPayloads::computeTokenDepositOnL1Message(
            l2TokenAddress,
            tokenId,
            amount,
            l1Recipient,
            tokenStandard
        );

        // send deposit request to L1
        starknet::syscalls::send_message_to_l1_syscall(
            to_address: l1KassAddress().into(),
            payload: message_payload.span()
        );
    }

    #[external]
    fn deposit721(l1Recipient: EthAddress, l2TokenAddress: starknet::ContractAddress, tokenId: u256) {
        _deposit(
            :l2TokenAddress,
            :l1Recipient,
            :tokenId,
            amount: u256 { low: 1, high: 0 },
            tokenStandard: TokenStandard::ERC721(())
        );
    }

    #[external]
    fn deposit1155(l1Recipient: EthAddress, l2TokenAddress: starknet::ContractAddress, tokenId: u256, amount: u256) {
        _deposit(:l2TokenAddress, :l1Recipient, :tokenId, :amount, tokenStandard: TokenStandard::ERC721(()));
    }

    // WITHDRAW

    fn _withdraw(
        l2TokenAddress: starknet::ContractAddress,
        l2Recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256,
        native: bool,
        tokenStandard: TokenStandard
    ) {
        let contractAddress = starknet::get_contract_address();

        // transfer tokens
        if (native) {
            match tokenStandard {
                TokenStandard::ERC721(_) => {
                    IERC721Dispatcher { contract_address: l2TokenAddress }.transferFrom(
                        contractAddress,
                        l2Recipient,
                        tokenId
                    );
                },
                TokenStandard::ERC1155(_) => {
                    IERC1155Dispatcher { contract_address: l2TokenAddress }.safeTransferFrom(
                        contractAddress,
                        l2Recipient,
                        tokenId,
                        amount,
                        ArrayTrait::<felt252>::new()
                    );
                }
            }
        } else {
            match tokenStandard {
                TokenStandard::ERC721(_) => {
                    IERC721Dispatcher { contract_address: l2TokenAddress }.mint(l2Recipient, tokenId);
                },
                TokenStandard::ERC1155(_) => {
                    IERC1155Dispatcher { contract_address: l2TokenAddress }.mint(l2Recipient, tokenId, amount);
                }
            }
        }
    }

    #[l1_handler]
    fn withdrawNative721(
        from_address: felt252,
        l2TokenAddress: starknet::ContractAddress,
        l2Recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body
        _withdraw(
            :l2TokenAddress,
            :l2Recipient,
            :tokenId,
            amount: u256 { low: 1, high: 0 },
            native: true,
            tokenStandard: TokenStandard::ERC721(())
        );
    }

    #[l1_handler]
    fn withdrawNative1155(
        from_address: felt252,
        l2TokenAddress: starknet::ContractAddress,
        l2Recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body
        _withdraw(
            :l2TokenAddress,
            :l2Recipient,
            :tokenId,
            :amount,
            native: true,
            tokenStandard: TokenStandard::ERC1155(())
        );
    }

    #[l1_handler]
    fn withdrawWrapped721(
        from_address: felt252,
        l2TokenAddress: starknet::ContractAddress,
        l2Recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body
        _withdraw(
            :l2TokenAddress,
            :l2Recipient,
            :tokenId,
            amount: u256 { low: 1, high: 0 },
            native: false,
            tokenStandard: TokenStandard::ERC721(())
        );
    }

    #[l1_handler]
    fn withdrawWrapped1155(
        from_address: felt252,
        l2TokenAddress: starknet::ContractAddress,
        l2Recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) {
        // modifiers
        _l1_handler(EthAddressTrait::new(from_address));

        // body
        _withdraw(
            :l2TokenAddress,
            :l2Recipient,
            :tokenId,
            :amount,
            native: false,
            tokenStandard: TokenStandard::ERC1155(())
        );
    }

    // MISC

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

    // INTERNALS

    fn _isInitialized(classHash: starknet::ClassHash) -> bool {
        _initializedClassHashes::read(classHash)
    }

    fn _setInitialized(classHash: starknet::ClassHash) {
        _initializedClassHashes::write(classHash, true);
    }

    fn _lockTokens() {

    }

    fn _unlockTokens() {

    }
}
