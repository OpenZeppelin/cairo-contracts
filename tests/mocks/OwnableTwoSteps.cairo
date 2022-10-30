%lang starknet 

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.ownableTwoSteps.library import OwnableTwoSteps

@constructor 
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (owner: felt) {
    OwnableTwoSteps.initializer(owner);
    return ();
}

@view
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt) {
    return OwnableTwoSteps.owner();
}

@view
func pendingOwner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (pending_owner: felt) {
    return OwnableTwoSteps.pending_owner();
}

@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pending_owner: felt
) {
    OwnableTwoSteps.transfer_ownership(pending_owner);
    return ();
}

@external
func acceptOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    OwnableTwoSteps.accept_ownership();
    return ();
}

@external
func cancelOwnershipProposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    OwnableTwoSteps.cancel_proposal();
    return ();
}

@external
func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    OwnableTwoSteps.renounce_ownership();
    return ();
}
