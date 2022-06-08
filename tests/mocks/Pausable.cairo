# SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.security.pausable import Pausable

@storage_var
func drastic_measure_taken() -> (res: felt):
end

@storage_var
func count() -> (res: felt):
end

@view
func isPaused{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (isPaused: felt):
    let (isPaused) = Pausable.is_paused()
    return (isPaused)
end

@view
func getCount{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = count.read()
    return (res)
end

@view
func getDrasticMeasureTaken{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = drastic_measure_taken.read()
    return (res)
end

@external
func normalProcess{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    Pausable.assert_not_paused()

    let (currentCount) = count.read()
    count.write(currentCount + 1)
    return ()
end

@external
func drasticMeasure{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    Pausable.assert_paused()

    drastic_measure_taken.write(TRUE)
    return ()
end

@external
func pause{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    Pausable._pause()
    return ()
end

@external
func unpause{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    Pausable._unpause()
    return ()
end
