use starknet::contract_address::ContractAddressSerde;

#[abi]
trait IERC1155 {
    fn uri(token_id: u256) -> Array::<felt252>;

    fn safeTransferFrom(
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        tokenId: u256,
        amount: u256,
        data: Array<felt252>
    ) -> u32;
}
