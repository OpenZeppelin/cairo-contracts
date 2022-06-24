# OwnableTwoStepsTransfer

This extensions allows contract ownership to be transferred via a two step method:

1. The owner of a contract proposes a new owner 
2. The proposed owner can accept the request or cancel it. Until this is accepted, they do not have control of the privileged functionality of the contract.

Both the current owner and the proposed owner can cancel the proposal, whereas only the proposed owner can accept it. 

## Benefits

A two step transfer can prevent mistakes where the owner of a contract transfers ownership to the wrong address, as this is an irreparable mistake. This is particulary useful in protocols that hold large amount of funds, as losing access to the privileged functionality could result into loss of funds. 
Please note that the ownership of the contract can still be resigned by calling `renounce_ownership`. 

## How to use it 

Please look into the `tests/mocks/OwnableTwoStepTransfer.cairo` mock contract to see a sample implementation. 

### Propose a new owner 

The contract owner should be calling the `propose_owner` function:

```
func propose_owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(proposed_owner: felt):
    let (caller) = get_caller_address()

    with_attr error_message("OwnableTwoStepTransfer: proposed owner nor caller cannot be the zero address"):
        assert_not_zero(proposed_owner * caller)
    end
    
    with_attr error_message("OwnableTwoStepTransfer: proposed owner cannot be the caller"):
        assert_not_equal(proposed_owner, caller)
    end 

    let (current_proposed) = OwnableTwoStepTransfer.proposed_owner()
    with_attr error_message("OwnableTwoStepTransfer: a proposal is already in motion"):
        assert current_proposed = 0
    end  

    assert_only_owner()

    _propose_owner(proposed_owner)
    return()
end
```

This function accepts one parameter, which is the proposed owner. This cannot be the zero address, and the function can only be called by the contract owner. Furthermore, if a proposal is already in motion, this should first be cancelled by the owner or the proposed owner.

It will emit an event with `currentOwner` and `proposedOwner`.

### Accept the ownership transfer

Should the proposed owner decide to accept ownership of the contract, the can call the `accept_ownership` function:

```
func accept_ownership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (proposed_owner) = OwnableTwoStepTransfer.proposed_owner()
    let (caller) = get_caller_address()
    # caller cannot be zero address to avoid overwriting owner when proposed_owner is not set
    with_attr error_message("OwnableTwoStepTransfer: caller is the zero address"):
        assert_not_zero(caller)
    end

    # no proposed ownership is in motion 
    with_attr error_message("OwnableTwoStepTransfer: a proposal is not in motion"):
        assert_not_zero(proposed_owner)
    end 

    with_attr error_message("OwnableTwoStepTransfer: caller is not the proposed owner"):
        assert caller = proposed_owner
    end

    _transfer_ownership(proposed_owner)
    return()
end
```

This function can only be called by either the current owner or the proposed owner. Events will be emitted the same way as the traditional ownable library (`previousOwner` and `newOwner`).

### Cancel a transfer proposal

Both the current owner and the proposed owner can cancel the proposal by calling the `cancel_ownership_proposal` function:

```
func cancel_ownership_proposal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local proposed_owner) = OwnableTwoStepTransfer.proposed_owner()

    with_attr error_message("OwnableTwoStepTransfer: no proposed owner to cancel"):
        assert_not_zero(proposed_owner)
    end

    let (local current_owner) = OwnableTwoStepTransfer.owner()
    let (local caller) = get_caller_address()

    # Can only be called by current owner or proposed owner
    with_attr error_message("OwnableTwoStepTransfer: caller is neither the current owner nor the proposed owner"):
        if caller != proposed_owner:
            assert caller = current_owner
        end
    end

    _reset_proposed_owner()
    # Emit event for cancellation with user who cancelled and the now old proposed owner
    OwnershipProposalCancelled.emit(caller, proposed_owner)
    return()
end
```

This will emit an event with the caller address and the `proposedOwner`.

