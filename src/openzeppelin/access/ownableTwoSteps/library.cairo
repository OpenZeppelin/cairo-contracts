// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.0 (access/ownableTwoSteps/library.cairo)

%lang starknet 

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero


//
// Events
//

@event
func OwnershipTransferred(previousOwner: felt, newOwner: felt) {
}

@event 
func OwnershipProposed(currentOwner: felt, newOwner: felt) {
}

@event 
func OwnershipProposalCancelled(caller: felt, pending_owner: felt) {
}

//
// Storage
//

@storage_var
func OwnableTwoSteps_owner() -> (owner: felt) {
}

@storage_var
func OwnableTwoSteps_pending_owner() -> (pending_owner: felt) {
}


namespace OwnableTwoSteps {

    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        _transfer_ownership(owner);
        return ();
    }

    //
    // Guards
    //

    func assert_only_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (owner) = OwnableTwoSteps.owner();
        let (caller) = get_caller_address();
        with_attr error_message("OwnableTwoSteps: caller is the zero address") {
            assert_not_zero(caller);
        }
        with_attr error_message("OwnableTwoSteps: caller is not the owner") {
            assert owner = caller;
        }
        return ();
    }

    //
    // Public
    //

    func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
        return OwnableTwoSteps_owner.read();
    }

    func pending_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (pending_owner: felt) {
        return OwnableTwoSteps_pending_owner.read();
    }

    func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pending_owner: felt) {
        with_attr error_message("OwnableTwoSteps: pending owner cannot be the zero address") {
            assert_not_zero(pending_owner);
        }

        with_attr error_message("OwnableTwoSteps: a proposal is already in motion") {
            let (current_pending_owner) = OwnableTwoSteps.pending_owner();
            assert current_pending_owner = 0;
        }

        assert_only_owner();
        _propose_owner(pending_owner);
        return ();
    }

    func accept_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (pending_owner) = OwnableTwoSteps.pending_owner();
        let (caller) = get_caller_address();
        
        // Caller cannot be the address zero to avoid overwriting the owner when the pending_owner is not set
        with_attr error_message("OwnableTwoSteps: caller is the zero address") {
            assert_not_zero(caller);
        }

        // Confirm that a proposal is in motion 
        with_attr error_message("OwnableTwoSteps: a proposal is not in motion") {
            assert_not_zero(pending_owner);
        }

        // Caller must be the proposed owner
        with_attr error_message("OwnableTwoSteps: caller is not the pending owner") {
            assert caller = pending_owner;
        }

        _transfer_ownership(pending_owner);
        return ();
    }

    func cancel_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        alloc_locals;

        let (pending_owner) = OwnableTwoSteps.pending_owner();

        // Confirm that a proposal is in motion 
        with_attr error_message("OwnableTwoSteps: a proposal is not in motion") {
            assert_not_zero(pending_owner);
        }

        let (current_owner) = OwnableTwoSteps.owner();
        let (caller) = get_caller_address();

        with_attr error_message("OwnableTwoSteps: caller is neither the current owner nor the pending owner") {
            if (caller != pending_owner) {
                assert caller = current_owner;
            }
        }

        _reset_pending_owner();

        // Emit cancellation event
        OwnershipProposalCancelled.emit(caller, pending_owner);
        return ();
    }

    func renounce_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        assert_only_owner();
        _transfer_ownership(0);
        return ();
    }

    //
    // Internal
    //

    func _transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_owner: felt) {
        alloc_locals;

        let (previous_owner: felt) = OwnableTwoSteps.owner();
        OwnableTwoSteps_owner.write(new_owner);
        // Reset pending owner
        _reset_pending_owner();
        OwnershipTransferred.emit(previous_owner, new_owner);
        return ();
    }

    func _propose_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pending_owner) {
        let (current_owner) = OwnableTwoSteps.owner();
        OwnableTwoSteps_pending_owner.write(pending_owner);
        OwnershipProposed.emit(current_owner, pending_owner);
        return ();
    }

    func _reset_pending_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() {
        OwnableTwoSteps_pending_owner.write(0);
        return ();
    }
}