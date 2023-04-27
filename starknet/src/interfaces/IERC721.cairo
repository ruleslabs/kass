use starknet::contract_address::ContractAddressSerde;

const IERC721_ID: u32 = 0x80ac58cd_u32;

#[abi]
trait IERC721 {
    fn name() -> felt252;
    fn symbol() -> felt252;

    fn transferFrom(
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        tokenId: u256
    ) -> u32;

    fn mint(
        to: starknet::ContractAddress,
        tokenId: u256
    ) -> u32;
}
