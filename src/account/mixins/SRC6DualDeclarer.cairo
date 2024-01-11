#[starknet::component]
mod SRC6DualDeclarer {
    use openzeppelin::account::interface;
    use starknet::account::Call;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(SRC6DualDeclarerImpl)]
    impl ISRC6DualDeclarer<
        TContractState, +HasComponent<TContractState>
    > of interface::ISRC6DualDeclarer<ComponentState<TContractState>> {
        fn __execute__(self: @ComponentState<TContractState>, calls: Array<Call>) -> Array<Span<felt252>> {
            self.__execute__(calls)
        }

        fn __validate__(self: @ComponentState<TContractState>, calls: Array<Call>) -> felt252 {
            self.__validate__(calls)
        }

        fn is_valid_signature(self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>) -> felt252 {
            self.is_valid_signature(hash, signature)
        }

        fn isValidSignature(self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>) -> felt252 {
            self.isValidSignature(hash, signature)
        }

        fn __validate_declare__(self: @ComponentState<TContractState>, class_hash: felt252) -> felt252 {
            self.__validate_declare__(class_hash)
        }
    }
}
