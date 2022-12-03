// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (upgrades/presets/Proxy.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import library_call, library_call_l1_handler

from openzeppelin.upgrades.library import Proxy

// @dev Cairo doesn't support native decoding like Solidity yet,
//      that's why we pass three arguments for calldata instead of one
// @param implementation_hash the implementation contract hash
// @param selector the implementation initializer function selector
// @param calldata_len the calldata length for the initializer
// @param calldata an array of felt containing the raw calldata
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    implementation_hash: felt, selector: felt,
    calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    Proxy._set_implementation_hash(implementation_hash);

    if (selector != 0) {
        // Initialize proxy from implementation
        library_call(
            class_hash=implementation_hash,
            function_selector=selector,
            calldata_size=calldata_len,
            calldata=calldata,
        );
    }

    return ();
}

//
// Fallback functions
//

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    let (class_hash) = Proxy.get_implementation_hash();

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return (retdata_size, retdata);
}

@l1_handler
@raw_input
func __l1_default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) {
    let (class_hash) = Proxy.get_implementation_hash();

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}
