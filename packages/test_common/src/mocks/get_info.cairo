#[starknet::interface]
pub trait IGetInfo<TContractState> {
    fn get_info(self: @TContractState) -> starknet::TxInfo;
}

#[starknet::contract]
pub mod GetInfoMock {
    use starknet::{TxInfo, get_execution_info};

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn get_info(self: @ContractState) -> TxInfo {
            let info = get_execution_info().unbox();
            info.tx_info.unbox()
        }
    }
}
