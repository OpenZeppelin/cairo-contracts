# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (upgrades/Proxy.cairo)

%lang starknet
#%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    library_call,
    library_call_l1_handler
)
from openzeppelin.upgrades.library import Proxy

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(implementation_hash: felt):
    Proxy._set_implementation_hash(implementation_hash)
    return ()
end

#
# Fallback functions
#

@external
@raw_input
@raw_output
func __default__{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        selector: felt,
        calldata_size: felt,
        calldata: felt*
    ) -> (
        retdata_size: felt,
        retdata: felt*
    ):
    let (class_hash) = Proxy.get_implementation_hash()

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    )
    return (retdata_size=retdata_size, retdata=retdata)
end


@l1_handler
@raw_input
func __l1_default__{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        selector: felt,
        calldata_size: felt,
        calldata: felt*
    ):
    let (class_hash) = Proxy.get_implementation_hash()

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    )
    return ()
end
