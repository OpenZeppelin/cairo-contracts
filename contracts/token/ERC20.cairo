%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_nn_le

@storage_var
func balances(user: felt) -> (res: felt):
end

@storage_var
func totalSupply() -> (res: felt):
end

@view
func decimals() -> (res: felt):
    return (18)
end

@view
func balanceOf{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (user: felt) -> (res: felt):
    let (res) = balances.read(user=user)
    return (res)
end

@external
func transfer{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (receiver: felt, amount: felt):
    let (sender) = get_caller_address()

    # validate sender has enough funds
    let (sender_balance) = balances.read(user=sender)
    assert_nn_le(amount, sender_balance)

    # substract from sender
    balances.write(sender, sender_balance - amount)

    # add to receiver
    let (res) = balances.read(user=receiver)
    balances.write(receiver, res + amount)

    return ()
end
