%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage

@storage_var
func _initialized() -> (res: felt):
end

@external
func initialized{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }() -> (res: felt):
    let (res) = _initialized.read()
    return (res=res)
end

@external
func initialize{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }():
    let (initialized) = _initialized.read()
    assert initialized = 0
    _initialized.write(1)
    return ()
end
