use starknet::contract_address::ContractAddressSerde;

const IERC1155_ID: u32 = 0xd9b67a26_u32;

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

    fn mint(
        to: starknet::ContractAddress,
        tokenId: u256,
        amount: u256
    ) -> u32;
}
