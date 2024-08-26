// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (presets/vesting.cairo)

#[starknet::contract]
pub mod VestingWallet {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::vesting::LinearVestingSchedule;
    use openzeppelin_finance::vesting::vesting::VestingComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: VestingComponent, storage: vesting, event: VestingEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Vesting
    #[abi(embed_v0)]
    impl VestingImpl = VestingComponent::VestingImpl<ContractState>;
    impl VestingInternalImpl = VestingComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        vesting: VestingComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        VestingEvent: VestingComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, beneficiary: ContractAddress, start: u64, duration: u64, cliff: u64
    ) {
        self.ownable.initializer(beneficiary);
        self.vesting.initializer(start, duration, cliff);
    }
}
