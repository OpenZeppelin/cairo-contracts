#[starknet::contract]
pub mod LinearVestingMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::{LinearVestingSchedule, VestingComponent};
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
        vesting: VestingComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        VestingEvent: VestingComponent::Event,
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
pub mod StepsVestingMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::VestingComponent;
    use openzeppelin_finance::vesting::VestingComponent::VestingScheduleTrait;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

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
        vesting: VestingComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        VestingEvent: VestingComponent::Event,
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

#[starknet::contract]
pub mod ERC20OptionalTransferPanicMock {
    use openzeppelin_token::erc20::interface::IERC20;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        transfer_should_fail: bool,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            if self.transfer_should_fail.read() {
                false
            } else {
                self.erc20.transfer(recipient, amount)
            }
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            if self.transfer_should_fail.read() {
                false
            } else {
                self.erc20.transfer_from(sender, recipient, amount)
            }
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn set_transfer_should_fail(ref self: ContractState, should_fail: bool) {
            self.transfer_should_fail.write(should_fail);
        }
    }
}
