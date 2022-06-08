# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.ownable_two_step_transfer import OwnableTwoStepTransfer

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    OwnableTwoStepTransfer.initializer(owner)
    return ()
end

@view
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = OwnableTwoStepTransfer.owner()
    return (owner=owner)
end

@view
func proposedOwner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (proposed_owner: felt):
    let (proposed_owner) = OwnableTwoStepTransfer.proposed_owner()
    return (proposed_owner=proposed_owner)
end

@external
func proposeOwner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(proposed_owner: felt):
    OwnableTwoStepTransfer.propose_owner(proposed_owner)
    return ()
end

@external
func acceptOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    OwnableTwoStepTransfer.accept_ownership()
    return ()
end

@external
func cancelOwnershipProposal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    OwnableTwoStepTransfer.cancel_ownership_proposal()
    return ()
end

@external
func renounceOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    OwnableTwoStepTransfer.renounce_ownership()
    return ()
end
