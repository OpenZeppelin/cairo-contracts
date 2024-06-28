// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (governance/timelock/timelock_controller.cairo)

/// # TimelockController Component
///
/// Component that acts as a timelocked controller. When set as the owner of an `Ownable` smart contract,
/// it enforces a timelock on all `only_owner` maintenance operations. This gives time for users
/// of the controlled contract to exit before a potentially dangerous maintenance operation is applied.
///
/// By default, this component is self administered, meaning administration tasks have to go through
/// the timelock process. The proposer role is in charge of proposing operations. A common use case
/// is to position the timelock controller as the owner of a smart contract, with a multi-sig
/// or a DAO as the sole proposer.
#[starknet::component]
pub mod TimelockControllerComponent {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent::{
        AccessControlImpl, AccessControlCamelImpl
    };
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::governance::timelock::interface::{ITimelock, TimelockABI};
    use openzeppelin::governance::timelock::utils::OperationState;
    use openzeppelin::governance::timelock::utils::call_impls::{HashCallImpl, Call};
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;

    // Constants
    pub const PROPOSER_ROLE: felt252 = selector!("PROPOSER_ROLE");
    pub const EXECUTOR_ROLE: felt252 = selector!("EXECUTOR_ROLE");
    pub const CANCELLER_ROLE: felt252 = selector!("CANCELLER_ROLE");
    const DONE_TIMESTAMP: u64 = 1;

    #[storage]
    struct Storage {
        TimelockController_timestamps: LegacyMap<felt252, u64>,
        TimelockController_min_delay: u64
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        CallScheduled: CallScheduled,
        CallExecuted: CallExecuted,
        CallSalt: CallSalt,
        Cancelled: Cancelled,
        MinDelayChange: MinDelayChange
    }

    /// Emitted when `call` is scheduled as part of operation `id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CallScheduled {
        #[key]
        pub id: felt252,
        #[key]
        pub index: felt252,
        pub call: Call,
        pub predecessor: felt252,
        pub delay: u64
    }

    /// Emitted when `call` is performed as part of operation `id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CallExecuted {
        #[key]
        pub id: felt252,
        #[key]
        pub index: felt252,
        pub call: Call
    }

    /// Emitted when a new proposal is scheduled with non-zero salt.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CallSalt {
        #[key]
        pub id: felt252,
        pub salt: felt252
    }

    /// Emitted when operation `id` is cancelled.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Cancelled {
        #[key]
        pub id: felt252
    }

    /// Emitted when the minimum delay for future operations is modified.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct MinDelayChange {
        pub old_duration: u64,
        pub new_duration: u64
    }

    pub mod Errors {
        pub const INVALID_OPERATION_LEN: felt252 = 'Timelock: invalid operation len';
        pub const INSUFFICIENT_DELAY: felt252 = 'Timelock: insufficient delay';
        pub const UNEXPECTED_OPERATION_STATE: felt252 = 'Timelock: unexpected op state';
        pub const UNEXECUTED_PREDECESSOR: felt252 = 'Timelock: awaiting predecessor';
        pub const UNAUTHORIZED_CALLER: felt252 = 'Timelock: unauthorized caller';
    }

    #[embeddable_as(TimelockImpl)]
    impl Timelock<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ITimelock<ComponentState<TContractState>> {
        /// Returns whether `id` corresponds to a registered operation.
        /// This includes the OperationStates: Waiting, Ready, and Done.
        fn is_operation(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) != OperationState::Unset
        }

        /// Returns whether the `id` OperationState is pending or not.
        /// Note that a pending operation may be either Waiting or Ready.
        fn is_operation_pending(self: @ComponentState<TContractState>, id: felt252) -> bool {
            let state = Timelock::get_operation_state(self, id);
            state == OperationState::Waiting || state == OperationState::Ready
        }

        /// Returns whether the `id` OperationState is Ready or not.
        fn is_operation_ready(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) == OperationState::Ready
        }

        /// Returns whether the `id` OperationState is Done or not.
        fn is_operation_done(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) == OperationState::Done
        }

        /// Returns the timestamp at which `id` becomes Ready.
        ///
        /// NOTE: `0` means the OperationState is Unset and `1` means the OperationState
        /// is Done.
        fn get_timestamp(self: @ComponentState<TContractState>, id: felt252) -> u64 {
            self.TimelockController_timestamps.read(id)
        }

        /// Returns the OperationState for `id`.
        fn get_operation_state(
            self: @ComponentState<TContractState>, id: felt252
        ) -> OperationState {
            let timestamp = Timelock::get_timestamp(self, id);
            if (timestamp == 0) {
                return OperationState::Unset;
            } else if (timestamp == DONE_TIMESTAMP) {
                return OperationState::Done;
            } else if (timestamp > starknet::get_block_timestamp()) {
                return OperationState::Waiting;
            } else {
                return OperationState::Ready;
            }
        }

        /// Returns the minimum delay in seconds for an operation to become valid.
        /// This value can be changed by executing an operation that calls `update_delay`.
        fn get_min_delay(self: @ComponentState<TContractState>) -> u64 {
            self.TimelockController_min_delay.read()
        }

        /// Returns the identifier of an operation containing a single transaction.
        fn hash_operation(
            self: @ComponentState<TContractState>, call: Call, predecessor: felt252, salt: felt252
        ) -> felt252 {
            PoseidonTrait::new()
                .update_with(@call)
                .update_with(predecessor)
                .update_with(salt)
                .finalize()
        }

        /// Returns the identifier of an operation containing a batch of transactions.
        fn hash_operation_batch(
            self: @ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252
        ) -> felt252 {
            PoseidonTrait::new()
                .update_with(@calls)
                .update_with(predecessor)
                .update_with(salt)
                .finalize()
        }

        /// Schedule an operation containing a single transaction.
        ///
        /// Requirements:
        ///
        /// - the caller must have the `PROPOSER_ROLE` role.
        ///
        /// Emits `CallScheduled` event.
        /// If `salt` is not zero, emits `CallSalt` event.
        fn schedule(
            ref self: ComponentState<TContractState>,
            call: Call,
            predecessor: felt252,
            salt: felt252,
            delay: u64
        ) {
            self.assert_only_role_or_open_role(PROPOSER_ROLE);

            let id = Timelock::hash_operation(@self, call, predecessor, salt);
            self._schedule(id, delay);
            self.emit(CallScheduled { id, index: 0, call, predecessor, delay });

            if salt != 0 {
                self.emit(CallSalt { id, salt });
            }
        }

        /// Schedule an operation containing a batch of transactions.
        ///
        /// Requirements:
        ///
        /// - the caller must have the `PROPOSER_ROLE` role.
        ///
        /// Emits one `CallScheduled` event for each transaction in the batch.
        /// If `salt` is not zero, emits `CallSalt` event.
        fn schedule_batch(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252,
            delay: u64
        ) {
            self.assert_only_role_or_open_role(PROPOSER_ROLE);

            let id = Timelock::hash_operation_batch(@self, calls, predecessor, salt);
            self._schedule(id, delay);

            let mut index = 0;
            loop {
                if index == calls.len() {
                    break;
                }

                let call = *calls.at(index);
                self.emit(CallScheduled { id, index: index.into(), call, predecessor, delay });
                index += 1;
            };

            if salt != 0 {
                self.emit(CallSalt { id, salt });
            }
        }

        /// Cancel an operation.
        ///
        /// Requirements:
        ///
        /// - The caller must have the `CANCELLER_ROLE` role.
        /// - `id` must be an operation.
        ///
        /// Emits a `Cancelled` event.
        fn cancel(ref self: ComponentState<TContractState>, id: felt252) {
            self.assert_only_role_or_open_role(CANCELLER_ROLE);
            assert(Timelock::is_operation_pending(@self, id), Errors::UNEXPECTED_OPERATION_STATE);

            self.TimelockController_timestamps.write(id, 0);
            self.emit(Cancelled { id });
        }

        /// Execute a (Ready) operation containing a single Call.
        ///
        /// Requirements:
        ///
        /// - Caller must have `EXECUTOR_ROLE`.
        /// - `id` must be in Ready OperationState.
        /// - `predecessor` must either be `0` or in Done OperationState.
        ///
        /// NOTE: This function can reenter, but it doesn't pose a risk because `_after_call`
        /// checks that the proposal is pending, thus any modifications to the operation during
        /// reentrancy should be caught.
        ///
        /// Emits a `CallExecuted` event.
        fn execute(
            ref self: ComponentState<TContractState>,
            call: Call,
            predecessor: felt252,
            salt: felt252
        ) {
            self.assert_only_role_or_open_role(EXECUTOR_ROLE);

            let id = Timelock::hash_operation(@self, call, predecessor, salt);
            self._before_call(id, predecessor);
            self._execute(call);
            self.emit(CallExecuted { id, index: 0, call });
            self._after_call(id);
        }

        /// Execute a (Ready) operation containing a batch of Calls.
        ///
        /// Requirements:
        ///
        /// - Caller must have `EXECUTOR_ROLE`.
        /// - `id` must be in Ready OperationState.
        /// - `predecessor` must either be `0` or in Done OperationState.
        ///
        /// NOTE: This function can reenter, but it doesn't pose a risk because `_after_call`
        /// checks that the proposal is pending, thus any modifications to the operation during
        /// reentrancy should be caught.
        ///
        /// Emits a `CallExecuted` event for each Call.
        fn execute_batch(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252
        ) {
            self.assert_only_role_or_open_role(EXECUTOR_ROLE);

            let id = Timelock::hash_operation_batch(@self, calls, predecessor, salt);
            self._before_call(id, predecessor);

            let mut index = 0;
            loop {
                if index == calls.len() {
                    break;
                }

                let call = *calls.at(index);
                self._execute(call);
                self.emit(CallExecuted { id, index: index.into(), call });
                index += 1;
            };

            self._after_call(id);
        }

        /// Changes the minimum timelock duration for future operations.
        ///
        /// Requirements:
        ///
        /// - The caller must be the timelock itself. This can only be achieved by scheduling
        /// and later executing an operation where the timelock is the target and the data
        /// is the serialized call to this function.
        ///
        /// Emits a `MinDelayChange` event.
        fn update_delay(ref self: ComponentState<TContractState>, new_delay: u64) {
            self.assert_only_self();

            let min_delay = self.TimelockController_min_delay.read();
            self.emit(MinDelayChange { old_duration: min_delay, new_duration: new_delay });

            self.TimelockController_min_delay.write(new_delay);
        }
    }

    #[embeddable_as(TimelockMixinImpl)]
    impl TimelockMixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of TimelockABI<ComponentState<TContractState>> {
        fn is_operation(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::is_operation(self, id)
        }

        fn is_operation_pending(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::is_operation_pending(self, id)
        }

        fn is_operation_ready(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::is_operation_ready(self, id)
        }

        fn is_operation_done(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::is_operation_done(self, id)
        }

        fn get_timestamp(self: @ComponentState<TContractState>, id: felt252) -> u64 {
            Timelock::get_timestamp(self, id)
        }

        fn get_operation_state(
            self: @ComponentState<TContractState>, id: felt252
        ) -> OperationState {
            Timelock::get_operation_state(self, id)
        }

        fn get_min_delay(self: @ComponentState<TContractState>) -> u64 {
            Timelock::get_min_delay(self)
        }

        fn hash_operation(
            self: @ComponentState<TContractState>, call: Call, predecessor: felt252, salt: felt252
        ) -> felt252 {
            Timelock::hash_operation(self, call, predecessor, salt)
        }

        fn hash_operation_batch(
            self: @ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252
        ) -> felt252 {
            Timelock::hash_operation_batch(self, calls, predecessor, salt)
        }

        fn schedule(
            ref self: ComponentState<TContractState>,
            call: Call,
            predecessor: felt252,
            salt: felt252,
            delay: u64
        ) {
            Timelock::schedule(ref self, call, predecessor, salt, delay);
        }

        fn schedule_batch(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252,
            delay: u64
        ) {
            Timelock::schedule_batch(ref self, calls, predecessor, salt, delay);
        }

        fn cancel(ref self: ComponentState<TContractState>, id: felt252) {
            Timelock::cancel(ref self, id);
        }

        fn execute(
            ref self: ComponentState<TContractState>,
            call: Call,
            predecessor: felt252,
            salt: felt252
        ) {
            Timelock::execute(ref self, call, predecessor, salt);
        }

        fn execute_batch(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252
        ) {
            Timelock::execute_batch(ref self, calls, predecessor, salt);
        }

        fn update_delay(ref self: ComponentState<TContractState>, new_delay: u64) {
            Timelock::update_delay(ref self, new_delay);
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }

        // IAccessControl
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            let access_control = get_dep_component!(self, AccessControl);
            access_control.has_role(role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            let access_control = get_dep_component!(self, AccessControl);
            access_control.get_role_admin(role)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.grant_role(role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.revoke_role(role, account);
        }
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.renounce_role(role, account);
        }

        // IAccessControlCamel
        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            let access_control = get_dep_component!(self, AccessControl);
            access_control.hasRole(role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            let access_control = get_dep_component!(self, AccessControl);
            access_control.getRoleAdmin(role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.grantRole(role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.revokeRole(role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            access_control.renounceRole(role, account);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering support for SRC5 and AccessControl.
        ///
        /// This function also configures the contract with the following parameters:
        ///
        /// - `min_delay`: initial minimum delay in seconds for operations.
        /// - `proposers`: accounts to be granted proposer and canceller roles.
        /// - `executors`: accounts to be granted executor role.
        /// - `admin`: optional account to be granted admin role; disable with zero address.
        ///
        /// WARNING: The optional admin can aid with initial configuration of roles after deployment
        /// without being subject to delay, but this role should be subsequently renounced in favor of
        /// administration through timelocked proposals.
        ///
        /// Emits two `RoleGranted` events for each account in `proposers` with `PROPOSER_ROLE` admin
        /// `CANCELLER_ROLE` roles.
        ///
        /// Emits a `RoleGranted` event for each account in `executors` with `EXECUTOR_ROLE` role.
        ///
        /// May emit a `RoleGranted` event for `admin` with `DEFAULT_ADMIN_ROLE` role (if `admin` is
        /// not zero).
        ///
        /// Emits `MinDelayChange` event.
        fn initializer(
            ref self: ComponentState<TContractState>,
            min_delay: u64,
            proposers: Span<ContractAddress>,
            executors: Span<ContractAddress>,
            admin: ContractAddress
        ) {
            // Register access control ID and self as default admin
            let mut access_component = get_dep_component_mut!(ref self, AccessControl);
            access_component.initializer();
            access_component._grant_role(DEFAULT_ADMIN_ROLE, starknet::get_contract_address());

            // Optional admin
            if admin != Zero::zero() {
                access_component._grant_role(DEFAULT_ADMIN_ROLE, admin)
            };

            // Register proposers and cancellers
            let mut i = 0;
            while i < proposers
                .len() {
                    let proposer = proposers.at(i);
                    access_component._grant_role(PROPOSER_ROLE, *proposer);
                    access_component._grant_role(CANCELLER_ROLE, *proposer);
                    i += 1;
                };

            // Register executors
            let mut i = 0;
            while i < executors
                .len() {
                    let executor = executors.at(i);
                    access_component._grant_role(EXECUTOR_ROLE, *executor);
                    i += 1;
                };

            // Set minimum delay
            self.TimelockController_min_delay.write(min_delay);
            self.emit(MinDelayChange { old_duration: 0, new_duration: min_delay })
        }

        /// Validates that the caller has the given `role`.
        /// If `role` is granted to the zero address, then this is considered an open role which
        /// allows anyone to be the caller.
        fn assert_only_role_or_open_role(self: @ComponentState<TContractState>, role: felt252) {
            let access_component = get_dep_component!(self, AccessControl);
            let is_role_open = access_component.has_role(role, Zero::zero());
            if !is_role_open {
                access_component.assert_only_role(role);
            }
        }

        /// Validates that the caller is the timelock contract itself.
        /// Otherwise it reverts.
        fn assert_only_self(self: @ComponentState<TContractState>) {
            let this = starknet::get_contract_address();
            let caller = starknet::get_caller_address();
            assert(caller == this, Errors::UNAUTHORIZED_CALLER);
        }

        /// Private function that checks before execution of an operation's calls.
        ///
        /// Requirements:
        ///
        /// - `id` must be in the Ready OperationState.
        /// - `predecessor` must either be zero or be in the Done OperationState.
        fn _before_call(self: @ComponentState<TContractState>, id: felt252, predecessor: felt252) {
            assert(Timelock::is_operation_ready(self, id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(
                predecessor == 0 || Timelock::is_operation_done(self, predecessor),
                Errors::UNEXECUTED_PREDECESSOR
            );
        }

        /// Private functions that checks after execution of an operation's calls.
        ///
        /// Requirements:
        ///
        /// - `id` must be in the Ready OperationState.
        fn _after_call(ref self: ComponentState<TContractState>, id: felt252) {
            assert(Timelock::is_operation_ready(@self, id), Errors::UNEXPECTED_OPERATION_STATE);
            self.TimelockController_timestamps.write(id, DONE_TIMESTAMP);
        }

        /// Private function that schedules an operation that is to become valid after a given `delay`.
        fn _schedule(ref self: ComponentState<TContractState>, id: felt252, delay: u64) {
            assert(!Timelock::is_operation(@self, id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(Timelock::get_min_delay(@self) <= delay, Errors::INSUFFICIENT_DELAY);
            self.TimelockController_timestamps.write(id, starknet::get_block_timestamp() + delay);
        }

        /// Private function that executes an operation's calls.
        fn _execute(ref self: ComponentState<TContractState>, call: Call) {
            let Call { to, selector, calldata } = call;
            starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall();
        }
    }
}
