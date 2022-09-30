// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.upgrades.library import Proxy, Proxy_initialized

//
// Storage
//

@storage_var
func value_1() -> (val: felt) {
}

//
// Initializer
//

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin: felt
) {
    Proxy.initializer(proxy_admin);
    return ();
}

@view
func initialized{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() 
-> (initialized: felt) {
    let (initialized) = Proxy_initialized.read();
    return (initialized=initialized);
}

//
// Upgrades
//

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

//
// Getters
//

@view
func getValue1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (val: felt) {
    return value_1.read();
}

//
// Setters
//

@external
func setValue1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(val: felt) {
    value_1.write(val);
    return ();
}
