// SPDX-License-Identifier: MIT

// This mock is to test functions from the ERC721 library
// that are not exposed in any preset like `_is_account`

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.token.erc721.library import ERC721, _is_account


@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt
) {
    ERC721.initializer(name, symbol);
    return ();
}

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@external
func isAccount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (isAccount: felt) {
    let (is_account) = _is_account(address);
    return (isAccount=is_account);
}
