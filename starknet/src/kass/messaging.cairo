use kass::utils::token_standard::ContractAddressInterfacesTrait;
#[contract]
mod Messaging {

    use starknet::ContractAddressIntoFelt252;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use traits::Into;
    use starknet::EthAddressZeroable;

    // INTERFACES

    use kass::interfaces::IERC721::IERC721Dispatcher;
    use kass::interfaces::IERC721::IERC721DispatcherTrait;

    use kass::interfaces::IERC1155::IERC1155Dispatcher;
    use kass::interfaces::IERC1155::IERC1155DispatcherTrait;

    // UTILS

    use kass::utils::EthAddressStorageAccess;
    use kass::utils::ArrayTConcatTrait;
    use kass::utils::TokenStandard;
    use kass::utils::token_standard::ContractAddressInterfacesTrait;

    // CONSTANTS

    use kass::constants::REQUEST_L1_721_INSTANCE;
    use kass::constants::REQUEST_L1_1155_INSTANCE;

    use kass::constants::CLAIM_OWNERSHIP;

    use kass::constants::TRANSFER_FROM_STARKNET;

    // STORAGE

    struct Storage {
        // L1 Address of the Kass contract
        _l1KassAddress: starknet::EthAddress,
    }

    // GETTERS

    #[view]
    fn l1KassAddress() -> starknet::EthAddress {
        _l1KassAddress::read()
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: starknet::EthAddress) {
        assert(l1KassAddress_.is_non_zero(), 'ZERO_L1_KASS_ADDRESS');

        _l1KassAddress::write(l1KassAddress_);
    }

    // L1 WRAPPER REQUEST

    fn computeL1WrapperRequestMessage(tokenAddress: starknet::ContractAddress) -> Array<felt252> {
        let mut payload: Array<felt252> = ArrayTrait::new();

        if (tokenAddress.isERC721()) {
            // token is ERC721
            payload.append(REQUEST_L1_721_INSTANCE.into());

            // store L2 token address
            payload.append(tokenAddress.into());

            // store wrapper init calldata
            let ERC721 = IERC721Dispatcher { contract_address: tokenAddress };

            payload.append(ERC721.name());
            payload.append(ERC721.symbol());
        } else if (tokenAddress.isERC1155()) {
            // token is ERC1155
            payload.append(REQUEST_L1_1155_INSTANCE.into());

            // store L2 token address
            payload.append(tokenAddress.into());

            // store wrapper init calldata
            let ERC1155 = IERC1155Dispatcher { contract_address: tokenAddress };
            let mut uri = ERC1155.uri(0.into());

            payload.concat(ref uri);
        } else {
            panic_with_felt252('Kass: Unkown token standard');
        }

        return payload;
    }

    fn sendL1WrapperRequestMessage(tokenAddress: starknet::ContractAddress) {
        let payload = computeL1WrapperRequestMessage(tokenAddress);

        // send wrapper request to L1
        starknet::syscalls::send_message_to_l1_syscall(to_address: l1KassAddress().into(), payload: payload.span());
    }

    // L1 OWNERSHIP REQUEST

    fn computeL1OwnershipRequest(
        tokenAddress: starknet::ContractAddress,
        l1Owner: starknet::EthAddress
    ) -> Array<felt252> {
        let mut payload: Array<felt252> = ArrayTrait::new();

        payload.append(CLAIM_OWNERSHIP.into());

        payload.append(tokenAddress.into());

        payload.append(l1Owner.into());

        return payload;
    }

    fn sendL1OwnershipRequestMessage(tokenAddress: starknet::ContractAddress, l1Owner: starknet::EthAddress) {
        let payload = computeL1OwnershipRequest(:tokenAddress, :l1Owner);

        // send ownership request to L1
        starknet::syscalls::send_message_to_l1_syscall(to_address: l1KassAddress().into(), payload: payload.span());
    }

    // DEPOSIT ON L1

    fn computeTokenDepositOnL1Message(
        tokenAddress: felt252,
        recipient: starknet::EthAddress,
        tokenId: u256,
        amount: u256
    ) -> Array<felt252> {
        let mut payload: Array<felt252> = ArrayTrait::new();

        payload.append(TRANSFER_FROM_STARKNET.into());

        payload.append(tokenAddress);

        payload.append(recipient.into());

        payload.append(tokenId.low.into());
        payload.append(tokenId.high.into());

        payload.append(amount.low.into());
        payload.append(amount.high.into());

        return payload;
    }

    fn sendTokenDepositMessage(
        tokenAddress: felt252,
        recipient: starknet::EthAddress,
        tokenId: u256,
        amount: u256
    ) {
        let payload = computeTokenDepositOnL1Message(:tokenAddress, :recipient, :tokenId, :amount);

        // send deposit request to L1
        starknet::syscalls::send_message_to_l1_syscall(to_address: l1KassAddress().into(), payload: payload.span());
    }
}
