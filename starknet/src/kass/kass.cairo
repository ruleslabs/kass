use kass::libraries::Upgradeable;

#[abi]
trait IKass {
    fn upgradeToAndCall(
        newClassHash: starknet::ClassHash,
        call: Upgradeable::Call
    );
}

#[contract]
mod Kass {

    // USES

    use starknet::ContractAddressIntoFelt252;
    use array::ArrayTrait;
    use integer::Felt252IntoU256;
    use integer::U128IntoFelt252;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use starknet::EthAddressIntoFelt252;
    use starknet::Felt252TryIntoEthAddress;
    use starknet::EthAddressSerde;
    use starknet::EthAddressZeroable;
    use starknet::StorageAccess;

    use kass::utils::ArrayTConcatTrait;
    use kass::utils::LegacyHashClassHash;
    use kass::utils::TokenStandard;
    use kass::utils::token_standard::ContractAddressInterfacesTrait;
    use kass::utils::EthAddressStorageAccess;

    use kass::TokenDeployer;
    use kass::Messaging;

    use kass::libraries::ownable::IOwnableDispatcher;
    use kass::libraries::ownable::IOwnableDispatcherTrait;

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
        // (implementation address => initialization status) mapping
        _initializedClassHashes: LegacyMap<starknet::ClassHash, bool>,
    }

    // MODIFIERS

    fn _initializer() {
        let classHash = starknet::class_hash_const::<0>(); // TODO: get current class hash

        assert(!_isInitialized(classHash), 'Already initialized');

        _setInitialized(classHash);
    }

    fn _l1_handler(from_address: starknet::EthAddress) {
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
    fn initialize(l1KassAddress_: starknet::EthAddress) {
        // modifiers
        _initializer();

        // body
        setL1KassAddress(l1KassAddress_);

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
    fn l1KassAddress() -> starknet::EthAddress {
        Messaging::l1KassAddress()
    }

    #[view]
    fn owner() {
        Ownable::getOwner();
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: starknet::EthAddress) {
        // modifiers
        Ownable::_onlyOwner();

        // body
        Messaging::setL1KassAddress(l1KassAddress_);
    }

    // TODO: init status support

    // WRAPPER CREATION

    #[l1_handler]
    fn createL2Wrapper721(
        from_address: felt252,
        l1TokenAddress: starknet::EthAddress,
        data: Array<felt252>
    ) {
        // modifiers
        _l1_handler(from_address.try_into().unwrap());

        // body

        // deploy Kass ERC 721
        TokenDeployer::deployKassERC721(l1TokenAddress.into(), data.span());
    }

    #[l1_handler]
    fn createL2Wrapper1155(
        from_address: felt252,
        l1TokenAddress: starknet::EthAddress,
        data: Array<felt252>
    ) {
        // modifiers
        _l1_handler(from_address.try_into().unwrap());

        // body

        // deploy Kass ERC 1155
        TokenDeployer::deployKassERC1155(l1TokenAddress.into(), data.span());
    }

    // WRAPPER REQUEST

    fn requestL1Wrapper(tokenAddress: starknet::ContractAddress) {
        // TODO: assert token is not a wrapper

        // send L1 Wrapper Creation message
        Messaging::sendL1WrapperRequestMessage(:tokenAddress);

        // TODO: emit event
    }

    // OWNERSHIP CLAIM

    #[l1_handler]
    fn claimL2Ownership(from_address: felt252, l1TokenAddress: starknet::EthAddress, l2Owner: starknet::ContractAddress) {
        // modifiers
        _l1_handler(from_address.try_into().unwrap());

        // get L2 token wrapper
        let l2TokenAddress = starknet::contract_address_const::<0>(); // TODO: compute contract address

        // transfer ownership
        IOwnableDispatcher { contract_address: l2TokenAddress }.transferOwnership(l2Owner);

        // emit event
    }

    // OWNERSHIP REQUEST

    fn requestL1Ownership(tokenAddress: starknet::ContractAddress, l1Owner: starknet::EthAddress) {
        // assert L2 token owner is sender
        let caller = starknet::get_caller_address();
        assert(
            IOwnableDispatcher { contract_address: tokenAddress }.getOwner() == caller,
            'Caller is not the owner'
        );

        // send L2 wrapper request message
        Messaging::sendL1OwnershipRequestMessage(:tokenAddress, :l1Owner);

        // emit event
    }

    // DEPOSIT

    fn _deposit(tokenAddress: felt252, l1Recipient: starknet::EthAddress, tokenId: u256, amount: u256) {
        // TODO: get real data
        let isNative = false;
        let l2TokenAddress = starknet::contract_address_const::<0x42>();

        // burn or tranfer tokens
        _lockTokens(tokenAddress: l2TokenAddress, :tokenId, :amount, :isNative);

        Messaging::sendTokenDepositMessage(:tokenAddress, recipient: l1Recipient, :tokenId, :amount);
    }

    #[external]
    fn deposit721(tokenAddress: felt252, l1Recipient: starknet::EthAddress, tokenId: u256) {
        _deposit(:tokenAddress, :l1Recipient, :tokenId, amount: u256 { low: 1, high: 0 });
    }

    #[external]
    fn deposit1155(tokenAddress: felt252, l1Recipient: starknet::EthAddress, tokenId: u256, amount: u256) {
        _deposit(:tokenAddress, :l1Recipient, :tokenId, :amount);
    }

    // WITHDRAW

    fn _withdraw(
        tokenAddress: felt252,
        recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256,
    ) {
        // TODO: get real data
        let isNative = false;
        let l2TokenAddress = starknet::contract_address_const::<0x42>();

        _unlockTokens(tokenAddress: l2TokenAddress, :recipient, :tokenId, :amount, :isNative);
    }

    #[l1_handler]
    fn withdraw721(from_address: felt252, tokenAddress: felt252, recipient: starknet::ContractAddress, tokenId: u256) {
        // modifiers
        _l1_handler(from_address.try_into().unwrap());

        // body
        _withdraw(:tokenAddress, :recipient, :tokenId, amount: u256 { low: 1, high: 0 });
    }

    #[l1_handler]
    fn withdraw1155(
        from_address: felt252,
        tokenAddress: felt252,
        recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) {
        // modifiers
        _l1_handler(from_address.try_into().unwrap());

        // body
        _withdraw(:tokenAddress, :recipient, :tokenId, :amount);
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

    fn _lockTokens(tokenAddress: starknet::ContractAddress, tokenId: u256, amount: u256, isNative: bool) {
        let caller = starknet::get_caller_address();
        let contractAddress = starknet::get_contract_address();

        if (tokenAddress.isERC721()) {
            let ERC721 = IERC721Dispatcher { contract_address: tokenAddress };

            if (isNative) {
                ERC721.transferFrom(from: caller, to: contractAddress, :tokenId);
            } else {
                // check if caller is owner before burning
                assert(ERC721.ownerOf(:tokenId) == caller, 'You do not own this token');

                ERC721.burn(:tokenId);
            }

            return ();
        } else if (tokenAddress.isERC1155()) {
            assert(amount > u256 {low: 0, high: 0 }, 'Cannot deposit null amount');

            let ERC1155 = IERC1155Dispatcher { contract_address: tokenAddress };

            if (isNative) {
                ERC1155.safeTransferFrom(
                    from: caller,
                    to: contractAddress,
                    :tokenId,
                    :amount,
                    data: ArrayTrait::<felt252>::new()
                );
            } else {
                ERC1155.burn(from: caller, :tokenId, :amount);
            }

            return ();
        } else {
            panic_with_felt252('Kass: Unkown token standard');
        }
    }

    fn _unlockTokens(
        tokenAddress: starknet::ContractAddress,
        recipient: starknet::ContractAddress,
        tokenId: u256,
        amount: u256,
        isNative: bool
    ) {
        let contractAddress = starknet::get_contract_address();

        if (tokenAddress.isERC721()) {
            let ERC721 = IERC721Dispatcher { contract_address: tokenAddress };

            if (isNative) {
                ERC721.transferFrom(from: contractAddress, to: recipient, :tokenId);
            } else {
                ERC721.mint(to: recipient, :tokenId);
            }

            return ();
        } else if (tokenAddress.isERC1155()) {
            assert(amount > u256 {low: 0, high: 0 }, 'Cannot withdraw null amount');

            let ERC1155 = IERC1155Dispatcher { contract_address: tokenAddress };

            if (isNative) {
                ERC1155.safeTransferFrom(
                    from: contractAddress,
                    to: recipient,
                    :tokenId,
                    :amount,
                    data: ArrayTrait::<felt252>::new()
                );
            } else {
                ERC1155.mint(to: recipient, :tokenId, :amount);
            }

            return ();
        } else {
            panic_with_felt252('Kass: Unkown token standard');
        }
    }
}
