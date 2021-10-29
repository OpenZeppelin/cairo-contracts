%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
#from starkware.starknet.common.storage import Storage
from starkware.starknet.common.syscalls import get_caller_address
from contracts.Initializable import initialized, initialize

@storage_var
func _owner() -> (res: felt):
end


@view
func get_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res: felt):
    let (res) = _owner.read()
    return (res=res)
end

@view
func only_owner{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} ():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    assert owner = caller
    return ()
end

@external
func initialize_ownable{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (initial_owner: felt):
    initialize()
    _owner.write(initial_owner)
    return ()
end

@external
func transfer_ownership{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (new_owner: felt) -> (new_owner: felt):
    only_owner()
    _owner.write(new_owner)
    return (new_owner=new_owner)
end
