// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (account/presets/AddressRegistry.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func L1_address(L2_address: felt) -> (address: felt) {
}

@external
func get_L1_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    L2_address: felt
) -> (address: felt) {
    return L1_address.read(L2_address);
}

@external
func set_L1_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_L1_address: felt
) {
    let (caller) = get_caller_address();
    L1_address.write(caller, new_L1_address);
    return ();
}
