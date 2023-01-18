// SPDX-License-Identifier: MIT

// This mock is to test functions from the ERC1155 library
// that are not exposed in any preset like `setURI`

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.token.erc1155.library import ERC1155, _is_account


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

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@external
func setURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(uri: felt) {
    ERC1155._set_uri(uri);
    return ();
}

@external
func isAccount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (isAccount: felt) {
    let (is_account) = _is_account(address);
    return (isAccount=is_account);
}

