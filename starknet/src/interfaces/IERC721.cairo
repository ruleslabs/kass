use starknet::contract_address::ContractAddressSerde;

#[abi]
trait IERC721 {
    fn name() -> felt252;
    fn symbol() -> felt252;

    fn transferFrom(
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        tokenId: u256
    ) -> u32;
}
