%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_nn_le

@storage_var
func owner(id: felt, number: felt) -> (res: felt):
end

@storage_var
func balance(owner: felt, id : felt) -> (res: felt):
end

@storage_var
func contract_uri() -> (res: *felt);
end

@storage_var
func  max_token_id() ->  (res: felt);
end

@view
func balance_of{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (owner: felt) -> (res: felt):
    let (res) = balance.read(owner=owner, id=id)
    return (res)
end

@view
func balance_of_batch{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (owner: felt) -> (res: felt):
    ###Have to make a sum
    let (res) = balance.read(owner=owner)
    return (res)
end


