#[contract]
mod TokenDeployer {

    use zeroable::Zeroable;
    use array::ArrayTrait;

    use starknet::ClassHashZeroable;

    // STORAGE

    struct Storage {
        // Address of the Kass ERC721 implementation
        _erc721ImplementationAddress: starknet::ClassHash,

        // Address of the Kass ERC1155 implementation
        _erc1155ImplementationAddress: starknet::ClassHash,
    }

    fn setDeployerClassHashes() {
        if (_erc721ImplementationAddress::read().is_zero()) {
            _erc721ImplementationAddress::write(starknet::class_hash_const::<0>()); // TODO: declare class hash
        }

        if (_erc1155ImplementationAddress::read().is_zero()) {
            _erc1155ImplementationAddress::write(starknet::class_hash_const::<0>()); // TODO: declare class hash
        }
    }

    fn deployKassERC721(salt: felt252, calldata: Span<felt252>) -> starknet::ContractAddress {
        let (contractAddress, _) = starknet::syscalls::deploy_syscall(
            class_hash: _erc721ImplementationAddress::read(),
            contract_address_salt: salt,
            :calldata,
            deploy_from_zero: true
        ).unwrap_syscall();

        return contractAddress;
    }

    fn deployKassERC1155(salt: felt252, calldata: Span<felt252>) -> starknet::ContractAddress {
        let (contractAddress, _) = starknet::syscalls::deploy_syscall(
            class_hash: _erc1155ImplementationAddress::read(),
            contract_address_salt: salt,
            :calldata,
            deploy_from_zero: true
        ).unwrap_syscall();

        return contractAddress;
    }
}
