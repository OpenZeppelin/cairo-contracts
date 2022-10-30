# OwnableTwoSteps

This library allows contract ownership to be transferred via a two step method:

1. The owner of a contract proposes a new owner
2. The proposed owner can accept the request or cancel it. Until this is accepted, they do not have control of the privileged functionality of the contract.

Both the current owner and the proposed owner can cancel the proposal, whereas only the proposed owner can accept it.

## Benefits

A two step transfer can prevent mistakes where the owner of a contract transfers ownership to the wrong address, as this is an irreparable mistake. This is particulary useful in protocols that hold large amount of funds, as losing access to the privileged functionality could result into loss of funds.
Please note that the ownership of the contract can still be resigned by calling `renounce_ownership`.

## How to use it

Please look into the `tests/mocks/OwnableTwoSteps.cairo` mock contract to see a sample implementation.

### Propose a new owner

The contract owner should be calling the `transfer_ownership` function:

```javascript
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
```

This function accepts one parameter, which is the pending owner. This cannot be the zero address, and the function can only be called by the contract owner. Furthermore, if a proposal is already in motion, this should first be cancelled by the owner or the pending owner.

It will emit an event with `currentOwner` and `pendingOwner`.

### Accept the ownership transfer

Should the proposed owner decide to accept ownership of the contract, the can call the `accept_ownership` function:

```javascript
func accept_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {       
    // Caller cannot be the address zero to avoid overwriting the owner when the pending_owner is not set
    with_attr error_message("OwnableTwoSteps: caller is the zero address") {
        let (caller) = get_caller_address();
        assert_not_zero(caller);
    }

    let (pending_owner) = OwnableTwoSteps.pending_owner();

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
```

This function can only be called by either the current owner or the proposed owner. Events will be emitted the same way as the traditional ownable library (`previousOwner` and `newOwner` will be the arguments).
Note that the pending owner storage variable will be reset.

### Cancel a transfer proposal

Both the current owner and the proposed owner can cancel the proposal by calling the `cancel_ownership_proposal` function:

```javascript
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
```

This will emit an event with the caller address and the `proposedOwner`.

### Renounce ownership

This library allows the owner to renounce ownership of the contract, by calling the `renounce_ownership` function. This works as the standard `ownable` version, however it also resets the pending owner.

```javascript
func renounce_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    assert_only_owner();
    _transfer_ownership(0);
    return ();
}
```