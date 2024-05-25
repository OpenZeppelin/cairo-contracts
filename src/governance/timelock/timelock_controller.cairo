// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock/timelock_controller.cairo)

use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use starknet::account::Call;

/// # TimelockController Component
///
///
#[starknet::component]
mod TimelockControllerComponent {
    use hash::{HashStateTrait, HashStateExTrait};
    use openzeppelin::access::accesscontrol::AccessControlComponent::AccessControlImpl;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::account::utils::execute_single_call;
    use openzeppelin::governance::timelock::interface::{ITimelock, OperationState};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent::InternalImpl as ERC1155InternalImpl;
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent;
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent::InternalImpl as ERC721InternalImpl;
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent;
    use super::{CallPartialEq, HashCallImpl};
    use poseidon::PoseidonTrait;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::account::Call;
    use zeroable::Zeroable;

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
    #[derive(Drop, starknet::Event)]
    enum Event {
        CallScheduled: CallScheduled,
        CallExecuted: CallExecuted,
        CallSalt: CallSalt,
        Cancelled: Cancelled,
        MinDelayChange: MinDelayChange
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallScheduled {
        #[key]
        calls: Span<Call>,
        predecessor: felt252,
        delay: u64
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallExecuted {
        #[key]
        id: felt252,
        #[key]
        calls: Span<Call>
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallSalt {
        #[key]
        id: felt252,
        salt: felt252
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Cancelled {
        #[key]
        id: felt252
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct MinDelayChange {
        old_duration: u64,
        new_duration: u64
    }

    mod Errors {
        const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
        const INVALID_OPERATION_LEN: felt252 = 'Timelock: invalid operation len';
        const INSUFFICIENT_DELAY: felt252 = 'Timelock: insufficient delay';
        const UNEXPECTED_OPERATION_STATE: felt252 = 'Timelock: unexpected op state';
        const UNEXECUTED_PREDECESSOR: felt252 = 'Timelock: unexecuted predessor';
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
            self.get_operation_state(id) != OperationState::Unset
        }

        fn is_operation_pending(self: @ComponentState<TContractState>, id: felt252) -> bool {
            let state = self.get_operation_state(id);
            state == OperationState::Waiting || state == OperationState::Ready
        }

        fn is_operation_ready(self: @ComponentState<TContractState>, id: felt252) -> bool {
            self.get_operation_state(id) == OperationState::Ready
        }

        fn is_operation_done(self: @ComponentState<TContractState>, id: felt252) -> bool {
            self.get_operation_state(id) == OperationState::Done
        }

        fn get_timestamp(self: @ComponentState<TContractState>, id: felt252) -> u64 {
            self.TimelockController_timestamps.read(id)
        }

        fn get_operation_state(
            self: @ComponentState<TContractState>, id: felt252
        ) -> OperationState {
            let timestamp = self.get_timestamp(id);
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
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252,
            delay: u64
        ) {
            self.assert_only_role(PROPOSER_ROLE);

            let id = self.hash_operation(calls, predecessor, salt);
            self._schedule(id, delay);
            self.emit(CallScheduled { calls, predecessor, delay });

            if salt != 0 {
                self.emit(CallSalt { id, salt });
            }
        }

        fn cancel(ref self: ComponentState<TContractState>, id: felt252) {
            self.assert_only_role(CANCELLER_ROLE);
            assert(self.is_operation_pending(id), Errors::UNEXPECTED_OPERATION_STATE);

            self.TimelockController_timestamps.write(id, 0);
            self.emit(Cancelled { id });
        }

        fn execute(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            predecessor: felt252,
            salt: felt252
        ) {
            self.assert_only_role(EXECUTOR_ROLE);

            let id = self.hash_operation(calls, predecessor, salt);
            self.before_call(id, predecessor);
            self._execute(calls);
            self.emit(CallExecuted { id, calls });
            self.after_call(id);
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
                i = i + 1;
            };

            // Register executors
            let mut i = 0;
            loop {
                if i == executors.len() {
                    break;
                }

                let mut executor = executors.at(i);
                access_component._grant_role(EXECUTOR_ROLE, *executor);
                i = i + 1;
            };

            self.emit(MinDelayChange { old_duration: 0, new_duration: min_delay })
        }

        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let access_component = get_dep_component!(self, AccessControl);
            access_component.assert_only_role(role);
        }

        fn before_call(self: @ComponentState<TContractState>, id: felt252, predecessor: felt252) {
            assert(self.is_operation_ready(id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(
                predecessor != 0 && !self.is_operation_done(predecessor),
                Errors::UNEXECUTED_PREDECESSOR
            );
        }

        fn after_call(ref self: ComponentState<TContractState>, id: felt252) {
            assert(!self.is_operation_ready(id), Errors::UNEXPECTED_OPERATION_STATE);
            self.TimelockController_timestamps.write(id, DONE_TIMESTAMP);
        }

        fn _schedule(ref self: ComponentState<TContractState>, id: felt252, delay: u64) {
            assert(self.is_operation(id), Errors::UNEXPECTED_OPERATION_STATE);
            assert(self.get_min_delay() < delay, Errors::INSUFFICIENT_DELAY);
            self.TimelockController_timestamps.write(id, starknet::get_block_timestamp() + delay);
        }

        fn _execute(ref self: ComponentState<TContractState>, mut calls: Span<Call>) {
            let mut index = 0;
            loop {
                if index == calls.len() {
                    break;
                }

                let mut call = Call {
                    to: *calls.at(index).to,
                    selector: *calls.at(index).selector,
                    calldata: *calls.at(index).calldata
                };
                execute_single_call(call);
            }
        }
    }
}


impl HashCallImpl<Call, S, +Serde<Call>, +HashStateTrait<S>, +Drop<S>> of Hash<@Call, S> {
    fn update_state(mut state: S, value: @Call) -> S {
        let mut arr = array![];
        Serde::serialize(value, ref arr);
        state = state.update(arr.len().into());
        while let Option::Some(elem) = arr.pop_front() {
            state = state.update(elem)
        };
        state
    }
}

impl CallPartialEq of PartialEq<Call> {
    #[inline(always)]
    fn eq(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        lhs_arr == rhs_arr
    }

    fn ne(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        !(lhs_arr == rhs_arr)
    }
}