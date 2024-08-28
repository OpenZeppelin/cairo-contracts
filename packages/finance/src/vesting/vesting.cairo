// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (finance/vesting/vesting.cairo)

/// # Vesting Component
///
/// A component for the controlled release of ERC-20 tokens to a designated beneficiary according
/// to a predefined vesting schedule. The implementing contract is required to implement `Ownable`
/// component, so that the owner of the contract is the vesting beneficiary. It also means that
/// ownership rights to the contract and to the vesting allocation can be assigned and transferred.
///
/// Vesting schedule is specified through the `VestingScheduleTrait` trait implementation.
/// This trait is intended to be used to implement any custom vesting schedules.
///
/// Any assets transferred to this contract will follow the vesting schedule as if they were locked
/// from the beginning. Consequently, if the vesting has already started, any amount of tokens sent
/// to this contract may be immediately releasable.
///
/// By setting the duration to 0, one can configure this contract to behave like an asset timelock
/// that hold tokens for a beneficiary until a specified time.
///
/// NOTE:
/// - A separate contract with a Vesting component must be deployed for each beneficiary.
/// - Can be used to vest multiple tokens to a single beneficiary, provided that the core vesting
///   parameters (start, duration, and cliff_duration) are identical.
/// - When using this contract with any token whose balance is adjusted automatically
///   (i.e. a rebase token), make sure to account the supply/balance adjustment in the
///   vesting schedule to ensure the vested amount is as intended.

use starknet::ContractAddress;

#[starknet::component]
pub mod VestingComponent {
    use openzeppelin_access::ownable::OwnableComponent::OwnableImpl;
    use openzeppelin_access::ownable::OwnableComponent;
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

    /// Emitted when an amount of the vested tokens is released to the beneficiary.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AmountReleased {
        #[key]
        pub token: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const INVALID_CLIFF_DURATION: felt252 = 'Vesting: Invalid cliff duration';
    }

    /// A trait that defines the logic for calculating the vested amount based on a given timestamp.
    pub trait VestingScheduleTrait<TContractState> {
        /// Calculates and returns the vested amount at a given `timestamp` based on the core
        /// vesting parameters.
        fn calculate_vested_amount(
            self: @ComponentState<TContractState>,
            token: ContractAddress,
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
        /// Returns the timestamp marking the beginning of the vesting period.
        fn start(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_start.read()
        }

        /// Returns the timestamp marking the end of the cliff period.
        fn cliff(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_cliff.read()
        }

        /// Returns the total duration of the vesting period.
        fn duration(self: @ComponentState<TContractState>) -> u64 {
            self.Vesting_duration.read()
        }

        /// Returns the timestamp marking the end of the vesting period.
        fn end(self: @ComponentState<TContractState>) -> u64 {
            self.start() + self.duration()
        }

        /// Returns the already released amount for a given `token`.
        fn released(self: @ComponentState<TContractState>, token: ContractAddress) -> u256 {
            self.Vesting_released.read(token)
        }

        /// Returns the amount of a given `token` that can be released at the time of the call.
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

        /// Returns the total vested amount of a specified `token` at a given `timestamp`.
        fn vested_amount(
            self: @ComponentState<TContractState>, token: ContractAddress, timestamp: u64
        ) -> u256 {
            self.resolve_vested_amount(token, timestamp)
        }

        /// Releases the amount of a given `token` that has already vested.
        ///
        /// Emits an `AmountReleased` event.
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
        /// Initializes the component by setting the vesting start, duration and cliff.
        /// To prevent reinitialization, this should only be used inside of a contract's
        /// constructor.
        fn initializer(
            ref self: ComponentState<TContractState>, start: u64, duration: u64, cliff_duration: u64
        ) {
            self.Vesting_start.write(start);
            self.Vesting_duration.write(duration);

            assert(cliff_duration <= duration, Errors::INVALID_CLIFF_DURATION);
            self.Vesting_cliff.write(start + cliff_duration);
        }

        /// Returns the vested amount that's calculated using the `VestingScheduleTrait`
        /// implementation.
        fn resolve_vested_amount(
            self: @ComponentState<TContractState>, token: ContractAddress, timestamp: u64
        ) -> u256 {
            let released_amount = self.Vesting_released.read(token);
            let total_allocation = ERC20Utils::get_self_balance(token) + released_amount;
            let vested_amount = VestingSchedule::calculate_vested_amount(
                self,
                token,
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

/// Defines the logic for calculating the vested amount, incorporating a cliff period.
/// It returns 0 before the cliff ends. After the cliff period, the vested amount returned
/// is directly proportional to the time passed since the start of the vesting schedule.
pub impl LinearVestingSchedule<
    TContractState
> of VestingComponent::VestingScheduleTrait<TContractState> {
    fn calculate_vested_amount(
        self: @VestingComponent::ComponentState<TContractState>,
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
            (total_allocation * (timestamp - start).into()) / duration.into()
        }
    }
}
