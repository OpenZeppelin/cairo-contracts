// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (finance/vesting/vesting.cairo)

#[starknet::component]
pub mod VestingComponent {
    use openzeppelin_access::ownable::ownable::OwnableComponent::OwnableImpl;
    use openzeppelin_access::ownable::ownable::OwnableComponent;
    use openzeppelin_finance::vesting::interface;
    use openzeppelin_token::erc20::utils::ERC20Utils;
    use starknet::ContractAddress;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        Vesting_start: u64,
        Vesting_duration: u64,
        Vesting_cliff: u64,
        Vesting_released: Map<ContractAddress, u256>
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        AmountReleased: AmountReleased
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AmountReleased {
        #[key]
        pub token: ContractAddress,
        pub amount: u256,
    }

    pub trait VestingScheduleTrait<TContractState> {
        fn calculate_vested_amount(
            self: @ComponentState<TContractState>,
            total_allocation: u256,
            timestamp: u64,
            start: u64,
            duration: u64,
            cliff: u64,
        ) -> u256;
    }

    #[embeddable_as(VestingImpl)]
    impl Vesting<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +VestingScheduleTrait<TContractState>
    > of interface::IVesting<ComponentState<TContractState>> {
        fn start(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_start.read()
        }

        fn cliff(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_cliff.read()
        }

        fn duration(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_duration.read()
        }

        fn end(self: @ComponentState<TContractState>) -> u64 {
            self.start() + self.duration()
        }

        fn released(self: @ComponentState<TContractState>, token: ContractAddress) -> u256 {
            self.Vesting_released.read(token)
        }

        fn releasable(self: @ComponentState<TContractState>, token: ContractAddress) -> u256 {
            let now = starknet::get_block_timestamp();
            let vested_amount = self.resolve_vested_amount(token, now);
            let released_amount = self.released(token);
            if vested_amount >= released_amount {
                vested_amount - released_amount
            } else {
                0
            }
        }

        fn vested_amount(
            self: @ComponentState<TContractState>, token: ContractAddress, timestamp: u64
        ) -> u256 {
            self.resolve_vested_amount(token, timestamp)
        }

        fn release(ref self: ComponentState<TContractState>, token: ContractAddress) -> u256 {
            let amount = self.releasable(token);
            self.Vesting_released.write(token, self.Vesting_released.read(token) + amount);

            let beneficiary = get_dep_component!(@self, Ownable).owner();
            ERC20Utils::transfer(token, beneficiary, amount);
            self.emit(AmountReleased { token, amount });

            amount
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl VestingSchedule: VestingScheduleTrait<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, start: u64, duration: u64, cliff_duration: u64
        ) {
            self.Vesting_start.write(start);
            self.Vesting_duration.write(duration);

            assert(cliff_duration <= duration, 'Vesting: Invalid cliff duration');
            self.Vesting_cliff.write(start + cliff_duration);
        }

        fn resolve_vested_amount(
            self: @ComponentState<TContractState>, token: ContractAddress, timestamp: u64
        ) -> u256 {
            let released_amount = self.Vesting_released.read(token);
            let total_allocation = ERC20Utils::get_self_balance(token) + released_amount;
            let vested_amount = VestingSchedule::calculate_vested_amount(
                self,
                total_allocation,
                timestamp,
                self.Vesting_start.read(),
                self.Vesting_duration.read(),
                self.Vesting_cliff.read()
            );
            vested_amount
        }
    }
}

pub impl LinearVestingSchedule<
    TContractState
> of VestingComponent::VestingScheduleTrait<TContractState> {
    fn calculate_vested_amount(
        self: @VestingComponent::ComponentState<TContractState>,
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
            (total_allocation * (timestamp - start).into()) / duration.into()
        }
    }
}
