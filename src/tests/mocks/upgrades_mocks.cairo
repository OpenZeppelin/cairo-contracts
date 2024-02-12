// These contracts are mocks used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

use starknet::ClassHash;

#[starknet::interface]
trait IUpgradesV1<TState> {
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
    fn set_value(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn remove_selector(self: @TState);
}

#[starknet::contract]
mod UpgradesV1 {
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::ClassHash;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl InternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        value: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[abi(embed_v0)]
    impl UpgradesV1Impl of super::IUpgradesV1<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.upgradeable._upgrade(new_class_hash);
        }

        fn set_value(ref self: ContractState, val: felt252) {
            self.value.write(val);
        }

        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }

        fn remove_selector(self: @ContractState) {}
    }
}

#[starknet::interface]
trait IUpgradesV2<TState> {
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
    fn set_value(ref self: TState, val: felt252);
    fn set_value2(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn get_value2(self: @TState) -> felt252;
}

#[starknet::contract]
mod UpgradesV2 {
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::ClassHash;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl InternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        value: felt252,
        value2: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[abi(embed_v0)]
    impl UpgradesV2Impl of super::IUpgradesV2<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.upgradeable._upgrade(new_class_hash);
        }

        fn set_value(ref self: ContractState, val: felt252) {
            self.value.write(val);
        }

        fn set_value2(ref self: ContractState, val: felt252) {
            self.value2.write(val);
        }

        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }

        fn get_value2(self: @ContractState) -> felt252 {
            self.value2.read()
        }
    }
}
