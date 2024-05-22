// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock_controller.cairo)

/// # TimelockController Component
///
///
#[starknet::component]
mod TimelockControllerComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent::AccessControlImpl;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    use poseidon::PoseidonTrait;
    use hash::{HashStateTrait, HashStateExTrait};
    use starknet::SyscallResultTrait;


    // Constants
    const PROPOSER_ROLE: felt252 = selector!("PROPOSER_ROLE");
    const EXECUTOR_ROLE: felt252 = selector!("EXECUTOR_ROLE");
    const CANCELLER_ROLE: felt252 = selector!("CANCELLER_ROLE");
    const DONE_TIMESTAMP: u64 = 1;

    #[storage]
    struct Storage {
        TimelockController_timestamps: LegacyMap<u32, u64>,
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

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallScheduled {
        #[key]
        id: u32,
        #[key]
        index: felt252,
        target: ContractAddress,
        value: u256,
        _data: Span<felt252>,
        predecessor: u32,
        delay: u64
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallExecuted {
        #[key]
        id: u32,
        #[key]
        index: felt252,
        target: ContractAddress,
        value: u256,
        _data: Span<felt252>
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallSalt {
        #[key]
        id: u32,
        salt: u32
    }

    /// Emitted when...
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Cancelled {
        #[key]
        id: u32
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
        const UNEXPECTED_PREDECESSOR: felt252 = 'Timelock: unexpected predessor';
        const UNAUTHORIZED_CALLER: felt252 = 'Timelock: unauthorized caller';
    }

    #[generate_trait]
    impl ExternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
    > of ExternalTrait<TContractState>{
        fn is_operation(self: @ComponentState<TContractState>, id: u32) -> bool {
            true
        }

        fn is_operation_pending(self: @ComponentState<TContractState>, id: u32) -> bool {
            true
        }

        fn is_operation_ready(self: @ComponentState<TContractState>, id: u32) -> bool {
            true
        }

        fn is_operation_done(self: @ComponentState<TContractState>, id: u32) -> bool {
            true
        }

        fn get_timestamp(self: @ComponentState<TContractState>, id: u32) -> u64 {
            self.TimelockController_timestamps.read(id)
        }

        fn get_operation_state(self: @ComponentState<TContractState>, id: u32) -> OperationState {
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
            ref self: ComponentState<TContractState>,
            target: ContractAddress,
            value: u256,
            data: Span<felt252>,
            predecessor: u32,
            salt: u32
        ) -> felt252 {
            self.hash_operations(array![target].span(), array![value].span(), data, predecessor, salt)
        }

        fn hash_operations(
            ref self: ComponentState<TContractState>,
            targets: Span<ContractAddress>,
            values: Span<u256>,
            payloads: Span<felt252>,
            predecessor: u32,
            salt: u32
        ) -> felt252 {
            // todo
            1
        }

        fn schedule(
            ref self: ComponentState<TContractState>,
            target: ContractAddress,
            value: u256,
            data: Span<felt252>,
            predecessor: u32,
            salt: u32,
            delay: u64
        ) { // onlyRole(PROPOSER_ROLE)
            //bytes32 id = hashOperation(target, value, data, predecessor, salt);
            //_schedule(id, delay);
            //emit CallScheduled(id, 0, target, value, data, predecessor, delay);
            //if (salt != bytes32(0)) {
            //    emit CallSalt(id, salt);
            //}
        }

        fn schedule_batch(
            ref self: ComponentState<TContractState>,
            targets: Span<ContractAddress>,
            values: Span<u256>,
            payloads: Span<felt252>,
            predecessor: u32,
            salt: u32,
            delay: u64
        ) { // onlyRole(PROPOSER_ROLE)
            //if (targets.length != values.length || targets.length != payloads.length) {
            //    revert TimelockInvalidOperationLength(targets.length, payloads.length, values.length);
            //}

            //bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
            //_schedule(id, delay);
            //for (uint256 i = 0; i < targets.length; ++i) {
            //    emit CallScheduled(id, i, targets[i], values[i], payloads[i], predecessor, delay);
            //}
            //if (salt != bytes32(0)) {
            //    emit CallSalt(id, salt);
            //}
        }

    }

    #[derive(Drop)]
    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Document me...
        ///
        ///
        fn initializer(
            ref self: TContractState,
            min_delay: felt252,
            proposers: Span<ContractAddress>,
            executors: Span<ContractAddress>,
            admin: ContractAddress
        ) {}
    }
}
