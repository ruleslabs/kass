#[contract]
mod KassMessagingPayloads {

    use starknet::ContractAddressIntoFelt252;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use starknet::ClassHashZeroable;
    use traits::Into;

    use kass::utils::ArrayTConcatTrait;
    use kass::utils::TokenStandard;
    use kass::utils::EthAddress;

    // CONSTANTS

    use kass::constants::REQUEST_L1_721_INSTANCE;
    use kass::constants::REQUEST_L1_1155_INSTANCE;

    use kass::constants::TRANSFER_721_FROM_STARKNET;
    use kass::constants::TRANSFER_1155_FROM_STARKNET;

    fn l1InstanceCreationMessagePayload(
        l2TokenAddress: starknet::ContractAddress,
        ref data: Array<felt252>,
        tokenStandard: TokenStandard
    ) -> Array<felt252> {
        // load payload
        let mut message_payload: Array<felt252> = ArrayTrait::new();

        match tokenStandard {
            TokenStandard::ERC721(_) => {
                message_payload.append(REQUEST_L1_721_INSTANCE);
            },
            TokenStandard::ERC1155(_) => {
                message_payload.append(REQUEST_L1_1155_INSTANCE);
            }
        }

        message_payload.append(l2TokenAddress.into());

        message_payload.concat(ref data);

        return message_payload;
    }

    fn tokenDepositOnL1MessagePayload(
        l2TokenAddress: starknet::ContractAddress,
        tokenId: u256,
        amount: u256,
        l1Recipient: EthAddress,
        tokenStandard: TokenStandard
    ) -> Array<felt252> {
        // load payload
        let mut message_payload: Array<felt252> = ArrayTrait::new();

        match tokenStandard {
            TokenStandard::ERC721(_) => {
                message_payload.append(TRANSFER_721_FROM_STARKNET);
            },
            TokenStandard::ERC1155(_) => {
                message_payload.append(TRANSFER_1155_FROM_STARKNET);
            }
        }

        message_payload.append(TRANSFER_FROM_STARKNET);
        message_payload.append(l1Recipient.into());
        message_payload.append(l2TokenAddress.into());

        message_payload.append(tokenId.low.into());
        message_payload.append(tokenId.high.into());

        message_payload.append(amount.low.into());
        message_payload.append(amount.high.into());

        return message_payload;
    }
}
