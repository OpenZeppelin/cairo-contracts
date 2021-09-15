%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage
from starkware.starknet.common.syscall import get_caller_address
from Initializable import initialized, initialize

@storage_var
func owner() -> (res: felt):
end

@external
func initialize_ownable{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* } (initial_owner: felt):
    initialize()
    owner.write(intial_owner)
    return ()
end

@external
func transfer_ownership{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* }(new_owner: felt) -> (new_owner: felt):
    let owner = owner.read()
    assert owner = get_caller_address()
    owner.write(new_owner)
    return (new_owner=new_owner)
end
