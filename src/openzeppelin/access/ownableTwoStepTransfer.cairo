# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (access/ownableTwoStepTransfer.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal

#
# Events
#

@event
func OwnershipTransferred(previousOwner: felt, newOwner: felt):
end

@event
func OwnershipProposed(currentOwner: felt, proposedOwner: felt):
end

@event
func OwnershipProposalCancelled(caller: felt, proposedOwner: felt):
end

#
# Storage
#

@storage_var
func Ownable_owner() -> (owner: felt):
end

@storage_var
func Ownable_proposed_owner() -> (proposed_owner: felt):
end

namespace OwnableTwoStepTransfer:
    #
    # Constructor
    #

    func initializer{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(owner: felt):
        with_attr error_message("Ownable: owner cannot be the zero address"):
            assert_not_zero(owner)
        end
        _transfer_ownership(owner)
        return ()
    end

    #
    # Protector (Modifier)
    #

    func assert_only_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        let (owner) = Ownable.owner()
        let (caller) = get_caller_address()
        with_attr error_message("Ownable: caller is not the owner"):
            assert owner = caller
        end
        return ()
    end

    #
    # Public
    #

    func owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (owner: felt):
        let (owner) = Ownable_owner.read()
        return (owner=owner)
    end

    func proposed_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (proposed_owner: felt):
        let (proposed_owner) = Ownable_proposed_owner.read()
        return (proposed_owner=proposed_owner)
    end

    func propose_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(proposed_owner: felt):
        let (caller) = get_caller_address()

        with_attr error_message("Ownable: proposed owner nor caller cannot be the zero address"):
            assert_not_zero(proposed_owner * caller)
        end
        
        with_attr error_message("Ownable: proposed owner cannot be the caller"):
            assert_not_equal(proposed_owner, caller)
        end 

        let (current_proposed) = Ownable.proposed_owner()
        with_attr error_message("Ownable: a proposal is already in motion"):
            assert current_proposed = 0
        end  

        assert_only_owner()

        _propose_owner(proposed_owner)
        return()
    end

    func accept_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        let (proposed_owner) = Ownable.proposed_owner()
        let (caller) = get_caller_address()
        # caller cannot be zero address to avoid overwriting owner when proposed_owner is not set
        with_attr error_message("Ownable: caller is the zero address"):
            assert_not_zero(caller)
        end

        # no proposed ownership is in motion 
        with_attr error_message("Ownable: a proposal is not in motion"):
            assert_not_zero(proposed_owner)
        end 

        with_attr error_message("Ownable: caller is not the proposed owner"):
            assert caller = proposed_owner
        end

        _transfer_ownership(proposed_owner)
        return()
    end

    func cancel_ownership_proposal{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        alloc_locals
        let (local proposed_owner) = Ownable.proposed_owner()

        with_attr error_message("Ownable: no proposed owner to cancel"):
            assert_not_zero(proposed_owner)
        end

        let (local current_owner) = Ownable.owner()
        let (local caller) = get_caller_address()

        # Can only be called by current owner or proposed owner
        with_attr error_message("Ownable: caller is neither the current owner nor the proposed owner"):
            if caller != proposed_owner:
                assert caller = current_owner
            end
        end

        _reset_proposed_owner()
        # Emit event for cancellation with user who cancelled and the now old proposed owner
        OwnershipProposalCancelled.emit(caller, proposed_owner)
        return()
    end

    func renounce_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        assert_only_owner()
        _transfer_ownership(0)
        return ()
    end

    #
    # Internal
    #

    func _transfer_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(new_owner: felt):
        alloc_locals
        let (previous_owner: felt) = Ownable.owner()
        Ownable_owner.write(new_owner)
        # reset the proposed owner
        _reset_proposed_owner()
        OwnershipTransferred.emit(previous_owner, new_owner)
        return ()
    end

    func _propose_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(proposed_owner: felt):
        let (current_owner) = Ownable.owner()
        Ownable_proposed_owner.write(proposed_owner)
        OwnershipProposed.emit(current_owner, proposed_owner)
        return ()
    end

    func _reset_proposed_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        Ownable_proposed_owner.write(0)
        return ()
    end 
end
