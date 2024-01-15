// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (account/mixins/src6_declarer_deployer.cairo)

#[starknet::component]
mod SRC6DeclarerDeployerMixin {
    use openzeppelin::account::AccountComponent::{DeclarerImpl, DeployableImpl};
    use openzeppelin::account::AccountComponent::{SRC6Impl, SRC6CamelOnlyImpl};
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::mixins::interface;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::account::Call;

    #[storage]
    struct Storage {}

    #[embeddable_as(SRC6DeclarerDeployerMixinImpl)]
    impl SRC6DeclarerDeployerMixin<
        TContractState,
        +HasComponent<TContractState>,
        +AccountComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ISRC6DeclarerDeployerMixin<ComponentState<TContractState>> {
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

        // IDeclarer
        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252
        ) -> felt252 {
            let account = self.get_account();
            account.__validate_declare__(class_hash)
        }

        // IDeployable
        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            public_key: felt252
        ) -> felt252 {
            let account = self.get_account();
            account.__validate_deploy__(class_hash, contract_address_salt, public_key)
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            let contract = self.get_contract();
            let src5 = SRC5Component::HasComponent::<TContractState>::get_component(contract);
            src5.supports_interface(interface_id)
        }
    }

    #[generate_trait]
    impl GetDepImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccountComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetDepTrait<TContractState> {
        fn get_account(
            self: @ComponentState<TContractState>
        ) -> @AccountComponent::ComponentState::<TContractState> {
            let contract = self.get_contract();
            AccountComponent::HasComponent::<TContractState>::get_component(contract)
        }
    }
}
