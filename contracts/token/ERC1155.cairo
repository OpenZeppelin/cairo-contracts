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