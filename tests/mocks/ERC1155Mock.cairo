// SPDX-License-Identifier: MIT

// This mock is to test functions from the ERC1155 library
// that are not exposed in any preset like `setURI`

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc1155.library import ERC1155


@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    uri: felt, owner: felt
) {
    ERC1155.initializer(uri);
    return ();
}

@view
func uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: Uint256) -> (
    uri: felt
) {
    return ERC1155.uri(id);
}


@external
func setURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(uri: felt) {
    ERC1155._set_uri(uri);
    return ();
}
