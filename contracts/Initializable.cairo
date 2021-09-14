%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_lt

@storage_var
func initialized() -> (res: felt):
end

@external
func initialize{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* }():
    assert_lt(initialized, 1)
    initialized.write(1)
    return ()
end
