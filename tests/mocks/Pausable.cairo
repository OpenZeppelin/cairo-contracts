// SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.security.pausable.library import Pausable

@storage_var
func drastic_measure_taken() -> (success: felt) {
}

@storage_var
func counter() -> (count: felt) {
}

@view
func isPaused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    paused: felt
) {
    return Pausable.is_paused();
}

@view
func getCount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (count: felt) {
    return counter.read();
}

@view
func getDrasticMeasureTaken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    success: felt
) {
    return drastic_measure_taken.read();
}

@external
func normalProcess{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Pausable.assert_not_paused();

    let (currentCount) = counter.read();
    counter.write(currentCount + 1);
    return ();
}

@external
func drasticMeasure{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Pausable.assert_paused();

    drastic_measure_taken.write(TRUE);
    return ();
}

@external
func pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Pausable._pause();
    return ();
}

@external
func unpause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Pausable._unpause();
    return ();
}
