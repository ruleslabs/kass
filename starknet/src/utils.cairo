mod concat;
use concat::ArrayTConcatTrait;

mod hash;
use hash::LegacyHashClassHash;

mod eth_address;
use eth_address::EthAddress;
use eth_address::EthAddressTrait;

#[derive(Copy, Drop)]
enum TokenStandard {
    ERC721: (),
    ERC1155: ()
}
