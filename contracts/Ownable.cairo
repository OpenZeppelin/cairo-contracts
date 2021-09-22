%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage
from starkware.starknet.common.syscalls import get_caller_address
from contracts.Initializable import initialized, initialize

@storage_var
func _owner() -> (res: felt):
end

@external
func get_owner{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }() -> (res: felt):
    let (res) = _owner.read()
    return (res=res)
end

@external
func initialize_ownable{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (initial_owner: felt):
    initialize()
    _owner.write(initial_owner)
    return ()
end

@external
func transfer_ownership{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (new_owner: felt) -> (new_owner: felt):
    let (owner) = _owner.read()
    let (caller) = get_caller_address()

    assert owner = caller

    _owner.write(new_owner)
    return (new_owner=new_owner)
end
