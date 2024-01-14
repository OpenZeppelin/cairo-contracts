// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (account/mixins/src6.cairo)

#[starknet::component]
mod SRC6Mixin {
    use openzeppelin::account::AccountComponent::{SRC6Impl, SRC6CamelOnlyImpl};
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::mixins::interface;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::account::Call;

    #[storage]
    struct Storage {}

    #[embeddable_as(SRC6MixinImpl)]
    impl SRC6Mixin<
        TContractState,
        +HasComponent<TContractState>,
        +AccountComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ISRC6Mixin<ComponentState<TContractState>> {
        // ISRC6
        fn __execute__(
            self: @ComponentState<TContractState>, calls: Array<Call>
        ) -> Array<Span<felt252>> {
            let account = self.get_account();
            account.__execute__(calls)
        }

        fn __validate__(self: @ComponentState<TContractState>, calls: Array<Call>) -> felt252 {
            let account = self.get_account();
            account.__validate__(calls)
        }

        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            let account = self.get_account();
            account.is_valid_signature(hash, signature)
        }

        // ISRC6CamelOnly
        fn isValidSignature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            let account = self.get_account();
            account.isValidSignature(hash, signature)
        }
    }

    #[generate_trait]
    impl GetAccountImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccountComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetAccountTrait<TContractState> {
        fn get_account(
            self: @ComponentState<TContractState>
        ) -> @AccountComponent::ComponentState::<TContractState> {
            let contract = self.get_contract();
            AccountComponent::HasComponent::<TContractState>::get_component(contract)
        }

        fn get_account_mut(
            ref self: ComponentState<TContractState>
        ) -> AccountComponent::ComponentState::<TContractState> {
            let mut contract = self.get_contract_mut();
            AccountComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
