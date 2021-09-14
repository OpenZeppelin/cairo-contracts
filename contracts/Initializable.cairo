%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage

@storage_var
func initialized() -> (res: felt):
end

@external
func initialize{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* }():
    let initialized = initialized.read()
    assert initialized = 0
    initialized.write(1)
    return ()
end
