use kass::utils::token_standard::ContractAddressInterfacesTrait;
#[contract]
mod KassMessaging {

    use starknet::ContractAddressIntoFelt252;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use traits::Into;

    use kass::utils::ArrayTConcatTrait;
    use kass::utils::TokenStandard;
    use kass::utils::EthAddress;
    use kass::utils::EthAddressTrait; // TODO try to remove
    use kass::utils::eth_address::EthAddressZeroable;
    use kass::utils::token_standard::ContractAddressInterfacesTrait;

    use kass::interfaces::IERC721::IERC721Dispatcher;
    use kass::interfaces::IERC721::IERC721DispatcherTrait;

    use kass::interfaces::IERC1155::IERC1155Dispatcher;
    use kass::interfaces::IERC1155::IERC1155DispatcherTrait;

    // CONSTANTS

    use kass::constants::REQUEST_L1_721_INSTANCE;
    use kass::constants::REQUEST_L1_1155_INSTANCE;

    use kass::constants::TRANSFER_FROM_STARKNET;

    // STORAGE

    struct Storage {
        // L1 Address of the Kass contract
        _l1KassAddress: EthAddress,
    }

    // GETTERS

    #[view]
    fn l1KassAddress() -> EthAddress {
        _l1KassAddress::read()
    }

    // SETTERS

    fn setL1KassAddress(l1KassAddress_: EthAddress) {
        assert(l1KassAddress_.is_non_zero(), 'ZERO_L1_KASS_ADDRESS');

        _l1KassAddress::write(l1KassAddress_);
    }

    // L1 WRAPPER REQUEST

    fn computeL1WrapperRequestMessage(l2TokenAddress: starknet::ContractAddress) -> Array<felt252> {
        // load payload
        let mut payload: Array<felt252> = ArrayTrait::new();

        if (l2TokenAddress.isERC721()) {
            // token is ERC721
            payload.append(REQUEST_L1_721_INSTANCE.into());

            // store L2 token address
            payload.append(l2TokenAddress.into());

            // store wrapper init calldata
            let ERC721 = IERC721Dispatcher { contract_address: l2TokenAddress };

            payload.append(ERC721.name());
            payload.append(ERC721.symbol());
        } else if (l2TokenAddress.isERC1155()) {
            // token is ERC1155
            payload.append(REQUEST_L1_1155_INSTANCE.into());

            // store L2 token address
            payload.append(l2TokenAddress.into());

            // store wrapper init calldata
            let ERC1155 = IERC1155Dispatcher { contract_address: l2TokenAddress };
            let mut uri = ERC1155.uri(0.into());

            payload.concat(ref uri);
        } else {
            panic_with_felt252('Kass: Unkown token standard');
        }

        return payload;
    }

    fn sendL1WrapperRequestMessage(l2TokenAddress: starknet::ContractAddress) {
        let paylaod = computeL1WrapperRequestMessage(l2TokenAddress);

        // send wrapper request to L1
        starknet::syscalls::send_message_to_l1_syscall(to_address: l1KassAddress().into(), payload: paylaod.span());
    }

    // DEPOSIT ON L1

    fn computeTokenDepositOnL1Message(
        tokenAddress: felt252,
        recipient: EthAddress,
        tokenId: u256,
        amount: u256
    ) -> Array<felt252> {
        // load payload
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
        recipient: EthAddress,
        tokenId: u256,
        amount: u256
    ) {
        let paylaod = computeTokenDepositOnL1Message(:tokenAddress, :recipient, :tokenId, :amount);

        // send deposit request to L1
        starknet::syscalls::send_message_to_l1_syscall(to_address: l1KassAddress().into(), payload: paylaod.span());
    }
}
