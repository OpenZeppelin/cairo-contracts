#[starknet::contract]
pub(crate) mod LinearVestingMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::{VestingComponent, LinearVestingSchedule};
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
        ref self: ContractState,
        beneficiary: ContractAddress,
        start: u64,
        duration: u64,
        cliff: u64,
    ) {
        self.ownable.initializer(beneficiary);
        self.vesting.initializer(start, duration, cliff);
    }
}

#[starknet::contract]
pub(crate) mod StepsVestingMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::interface::IVesting;
    use openzeppelin_finance::vesting::VestingComponent::VestingScheduleTrait;
    use openzeppelin_finance::vesting::VestingComponent;
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
        total_steps: u64,
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
        ref self: ContractState,
        total_steps: u64,
        beneficiary: ContractAddress,
        start: u64,
        duration: u64,
        cliff: u64,
    ) {
        self.total_steps.write(total_steps);
        self.ownable.initializer(beneficiary);
        self.vesting.initializer(start, duration, cliff);
    }

    impl VestingSchedule of VestingScheduleTrait<ContractState> {
        fn calculate_vested_amount(
            self: @VestingComponent::ComponentState<ContractState>,
            token: ContractAddress,
            total_allocation: u256,
            timestamp: u64,
            start: u64,
            duration: u64,
            cliff: u64,
        ) -> u256 {
            if timestamp < cliff {
                0
            } else if timestamp >= start + duration {
                total_allocation
            } else {
                let total_steps = self.get_contract().total_steps.read();
                let vested_per_step = total_allocation / total_steps.into();
                let step_duration = duration / total_steps;
                let current_step = (timestamp - start) / step_duration;
                let vested_amount = vested_per_step * current_step.into();
                vested_amount
            }
        }
    }
}
