use starknet::contract_address::ContractAddressSerde;

#[abi]
trait IERC1155 {
    fn uri(token_id: u256) -> Array::<felt>;

    fn safeTransferFrom(
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        amount: u256,
        data: Array<felt>
    ) -> u32;
}
