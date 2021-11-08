%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le

#
# Storage
#

@storage_var
func owner(token_type : felt, token_id : felt) -> (res : felt):
end

@storage_var
func balances(owner : felt, token_type : felt) -> (res : felt):
end

# @storage_var
# func contract_uri() -> (res: *felt);
# end

@storage_var
func  max_token_id() ->  (res: felt);
end

@storage_var
func operator_approvals(owner : felt, operator : felt) -> (res : felt):
end

@storage_var
func total_supply(token_type : felt) -> (res : felt):
end

@storage_var
func initialized() -> (res : felt):
end

#
# Initializer
#

@external
func initialize{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    let (sender) = get_caller_address()
    _mint(sender, 1, 1000)
    return ()
end

@external
func initialize_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        token_type_len : felt, token_type : felt*, amount_len : felt, amount : felt*):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    let (sender) = get_caller_address()
    _mint_batch(sender, token_type_len, token_type, amount_len, amount)
    return ()
end

func _mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_type : felt, amount : felt) -> ():
    let (res) = balances.read(owner=recipient, token_type=token_type)
    balances.write(recipient, token_type, res + amount)

    let (supply) = total_supply.read(token_type=token_type)
    total_supply.write(token_type, supply + amount)
    return ()
end

func _mint_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_type_len : felt, token_type : felt*, amount_len : felt,
        amount : felt*) -> ():
    assert token_type_len = amount_len
    if token_type_len == 0:
        return ()
    end
    _mint(recipient, token_type[0], amount[0])
    return _mint_batch(
        recipient=recipient,
        token_type_len=token_type_len - 1,
        token_type=token_type + 1,
        amount_len=amount_len - 1,
        amount=amount + 1)
end

#
# Getters
#

@view
func balance_of{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owner : felt, token_type : felt) -> (res : felt):
    let (res) = balances.read(owner=owner, token_type=token_type)
    return (res)
end

@view
func balance_of_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owner_len : felt, owner : felt*, token_type_len : felt, token_type : felt*) -> ():
    assert owner_len = token_type_len
    if owner_len == 0:
        return ()
    end
    balance_of(owner[0], token_type[0])
    return balance_of_batch(
        owner_len=owner_len - 1,
        owner=owner + 1,
        token_type_len=token_type_len - 1,
        token_type=token_type + 1)
end