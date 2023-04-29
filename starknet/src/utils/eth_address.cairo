use traits::TryInto;
use traits::Into;
use option::OptionTrait;
use starknet::StorageAccess;
use starknet::StorageBaseAddress;
use starknet::SyscallResult;
use starknet::Felt252TryIntoEthAddress;
use starknet::EthAddressIntoFelt252;

impl EthAddressStorageAccess of StorageAccess<starknet::EthAddress> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<starknet::EthAddress> {
        Result::Ok(
            StorageAccess::<felt252>::read(address_domain, base)?.try_into().expect('Non EthAddress')
        )
    }
    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: starknet::EthAddress) -> SyscallResult<()> {
        StorageAccess::<felt252>::write(address_domain, base, value.into())
    }
}
