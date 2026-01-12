use openzeppelin_utils::structs::bitmap::{BitMap, BitMapTrait};

#[starknet::interface]
pub trait IMockBitMap<TContractState> {
    fn get(self: @TContractState, index: u256) -> bool;
    fn set(ref self: TContractState, index: u256);
    fn unset(ref self: TContractState, index: u256);
    fn set_to(ref self: TContractState, index: u256, value: bool);
}

#[starknet::contract]
pub mod MockBitMap {
    use openzeppelin_utils::structs::bitmap::{BitMap, BitMapTrait};

    #[storage]
    struct Storage {
        bitmap: BitMap,
    }

    #[abi(embed_v0)]
    impl MockBitMapImpl of super::IMockBitMap<ContractState> {
        fn get(self: @ContractState, index: u256) -> bool {
            self.bitmap.deref().get(index)
        }

        fn set(ref self: ContractState, index: u256) {
            self.bitmap.deref().set(index);
        }

        fn unset(ref self: ContractState, index: u256) {
            self.bitmap.deref().unset(index);
        }

        fn set_to(ref self: ContractState, index: u256, value: bool) {
            self.bitmap.deref().set_to(index, value);
        }
    }
}
