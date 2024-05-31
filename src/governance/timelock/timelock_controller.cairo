// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock/timelock_controller.cairo)

/// # Timelock Controller Component
///
///
#[starknet::component]
mod TimelockControllerComponent {
    use hash::{HashStateTrait, HashStateExTrait};
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent::{
        AccessControlImpl, AccessControlCamelImpl
    };
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::governance::timelock::interface::{ITimelock, TimelockABI};
    use openzeppelin::governance::timelock::utils::OperationState;
    use openzeppelin::governance::timelock::utils::call_impls::{HashCallImpl, Call};
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent::{
        ERC1155ReceiverImpl, ERC1155ReceiverCamelImpl
    };
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent::{
        InternalImpl as ERC1155InternalImpl
    };
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent;
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent::InternalImpl as ERC721ReceiverInternalImpl;
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent::{
        ERC721ReceiverImpl, ERC721ReceiverCamelImpl
    };
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent;
    use poseidon::PoseidonTrait;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;

    // Constants
    const PROPOSER_ROLE: felt252 = selector!("PROPOSER_ROLE");
    const EXECUTOR_ROLE: felt252 = selector!("EXECUTOR_ROLE");
    const CANCELLER_ROLE: felt252 = selector!("CANCELLER_ROLE");
    const DONE_TIMESTAMP: u64 = 1;

    #[storage]
    struct Storage {
        TimelockController_timestamps: LegacyMap<felt252, u64>,
        TimelockController_min_delay: u64
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        CallScheduled: CallScheduled,
        CallExecuted: CallExecuted,
        CallSalt: CallSalt,
        Cancelled: Cancelled,
        MinDelayChange: MinDelayChange
    }

    /// Emitted when `call` is scheduled as part of operation `id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallScheduled {
        #[key]
        id: felt252,
        #[key]
        index: felt252,
        call: Call,
        predecessor: felt252,
        delay: u64
    }

    /// Emitted when `call` is performed as part of operation `id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallExecuted {
        #[key]
        id: felt252,
        #[key]
        index: felt252,
        call: Call
    }

    /// Emitted when a new proposal is scheduled with non-zero salt.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallSalt {
        #[key]
        id: felt252,
        salt: felt252
    }

    /// Emitted when operation `id` is cancelled.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Cancelled {
        #[key]
        id: felt252
    }

    /// Emitted when the minimum delay for future operations is modified.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct MinDelayChange {
        old_duration: u64,
        new_duration: u64
    }

    mod Errors {
        const INVALID_OPERATION_LEN: felt252 = 'Timelock: invalid operation len';
        const INSUFFICIENT_DELAY: felt252 = 'Timelock: insufficient delay';
        const UNEXPECTED_OPERATION_STATE: felt252 = 'Timelock: unexpected op state';
        const UNEXECUTED_PREDECESSOR: felt252 = 'Timelock: awaiting predecessor';
        const UNAUTHORIZED_CALLER: felt252 = 'Timelock: unauthorized caller';
    }

    #[embeddable_as(TimelockImpl)]
    impl Timelock<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +ERC721ReceiverComponent::HasComponent<TContractState>,
        +ERC1155ReceiverComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ITimelock<ComponentState<TContractState>> {
        fn is_operation(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) != OperationState::Unset
        }

        fn is_operation_pending(self: @ComponentState<TContractState>, id: felt252) -> bool {
            let state = Timelock::get_operation_state(self, id);
            state == OperationState::Waiting || state == OperationState::Ready
        }

        fn is_operation_ready(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) == OperationState::Ready
        }

        fn is_operation_done(self: @ComponentState<TContractState>, id: felt252) -> bool {
            Timelock::get_operation_state(self, id) == OperationState::Done
        }

        fn get_timestamp(self: @ComponentState<TContractState>, id: felt252) -> u64 {
            self.TimelockController_timestamps.read(id)
        }

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

        fn get_min_delay(self: @ComponentState<TContractState>) -> u64 {
            self.TimelockController_min_delay.read()
        }

        fn hash_operation(
            self: @ComponentState<TContractState>, call: Call, predecessor: felt252, salt: felt252
        ) -> felt252 {
            PoseidonTrait::new()
                .update_with(@call)
                .update_with(predecessor)
                .update_with(salt)
                .finalize()
        }

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

        fn cancel(ref self: ComponentState<TContractState>, id: felt252) {
            self.assert_only_role_or_open_role(CANCELLER_ROLE);
            assert(Timelock::is_operation_pending(@self, id), Errors::UNEXPECTED_OPERATION_STATE);

            self.TimelockController_timestamps.write(id, 0);
            self.emit(Cancelled { id });
        }

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

        fn update_delay(ref self: ComponentState<TContractState>, new_delay: u64) {
            let this = starknet::get_contract_address();
            let caller = starknet::get_caller_address();
            assert(caller == this, Errors::UNAUTHORIZED_CALLER);

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
        impl ERC721Receiver: ERC721ReceiverComponent::HasComponent<TContractState>,
        impl ERC1155Receiver: ERC1155ReceiverComponent::HasComponent<TContractState>,
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

        // IERC721Receiver
        fn on_erc721_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc721_receiver = get_dep_component!(self, ERC721Receiver);
            erc721_receiver.on_erc721_received(operator, from, token_id, data)
        }

        // IERC721ReceiverCamel
        fn onERC721Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc721_receiver = get_dep_component!(self, ERC721Receiver);
            erc721_receiver.onERC721Received(operator, from, tokenId, data)
        }

        // IERC1155Receiver
        fn on_erc1155_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc1155_receiver = get_dep_component!(self, ERC1155Receiver);
            erc1155_receiver.on_erc1155_received(operator, from, token_id, value, data)
        }

        fn on_erc1155_batch_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) -> felt252 {
            let erc1155_receiver = get_dep_component!(self, ERC1155Receiver);
            erc1155_receiver.on_erc1155_batch_received(operator, from, token_ids, values, data)
        }

        // IERC1155ReceiverCamel
        fn onERC1155Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc1155_receiver = get_dep_component!(self, ERC1155Receiver);
            erc1155_receiver.onERC1155Received(operator, from, tokenId, value, data)
        }

        fn onERC1155BatchReceived(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) -> felt252 {
            let erc1155_receiver = get_dep_component!(self, ERC1155Receiver);
            erc1155_receiver.onERC1155BatchReceived(operator, from, tokenIds, values, data)
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl ERC721Receiver: ERC721ReceiverComponent::HasComponent<TContractState>,
        impl ERC1155Receiver: ERC1155ReceiverComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Document me...
        ///
        ///
        fn initializer(
            ref self: ComponentState<TContractState>,
            min_delay: u64,
            proposers: Span<ContractAddress>,
            executors: Span<ContractAddress>,
            admin: ContractAddress
        ) {
            // Register as token receivers
            let mut erc721_receiver = get_dep_component_mut!(ref self, ERC721Receiver);
            erc721_receiver.initializer();

            let mut erc1155_receiver = get_dep_component_mut!(ref self, ERC1155Receiver);
            erc1155_receiver.initializer();

            // Self administration
            let mut access_component = get_dep_component_mut!(ref self, AccessControl);
            access_component._grant_role(DEFAULT_ADMIN_ROLE, starknet::get_contract_address());

            // Optional admin
            if admin != Zeroable::zero() {
                access_component._grant_role(DEFAULT_ADMIN_ROLE, admin)
            };

            // Register proposers and cancellers
            let mut i = 0;
            loop {
                if i == proposers.len() {
                    break;
                }

                let mut proposer = proposers.at(i);
                access_component._grant_role(PROPOSER_ROLE, *proposer);
                access_component._grant_role(CANCELLER_ROLE, *proposer);
                i += 1;
            };

            // Register executors
            let mut i = 0;
            loop {
                if i == executors.len() {
                    break;
                }

                let mut executor = executors.at(i);
                access_component._grant_role(EXECUTOR_ROLE, *executor);
                i += 1;
            };

            self.TimelockController_min_delay.write(min_delay);
            self.emit(MinDelayChange { old_duration: 0, new_duration: min_delay })
        }

        fn assert_only_role_or_open_role(self: @ComponentState<TContractState>, role: felt252) {
            let access_component = get_dep_component!(self, AccessControl);
            let is_role_open = access_component.has_role(role, Zeroable::zero());
            if !is_role_open {
                access_component.assert_only_role(role);
            }
        }

        fn _before_call(self: @ComponentState<TContractState>, id: felt252, predecessor: felt252) {
            assert(Timelock::is_operation_ready(self, id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(
                predecessor == 0 || Timelock::is_operation_done(self, predecessor),
                Errors::UNEXECUTED_PREDECESSOR
            );
        }

        fn _after_call(ref self: ComponentState<TContractState>, id: felt252) {
            assert(Timelock::is_operation_ready(@self, id), Errors::UNEXPECTED_OPERATION_STATE);
            self.TimelockController_timestamps.write(id, DONE_TIMESTAMP);
        }

        fn _schedule(ref self: ComponentState<TContractState>, id: felt252, delay: u64) {
            assert(!Timelock::is_operation(@self, id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(Timelock::get_min_delay(@self) <= delay, Errors::INSUFFICIENT_DELAY);
            self.TimelockController_timestamps.write(id, starknet::get_block_timestamp() + delay);
        }

        fn _execute(ref self: ComponentState<TContractState>, call: Call) {
            let Call { to, selector, calldata } = call;
            starknet::call_contract_syscall(to, selector, calldata).unwrap_syscall();
        }
    }
}
