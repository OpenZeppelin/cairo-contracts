// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (token/erc721/presets/utils/ERC721Holder.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.utils.constants.library import IERC721_RECEIVER_ID

from openzeppelin.introspection.erc165.library import ERC165

@view
func onERC721Received(
    operator: felt, from_: felt, tokenId: Uint256, data_len: felt, data: felt*
) -> (selector: felt) {
    return (selector=IERC721_RECEIVER_ID);
}

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    ERC165.register_interface(IERC721_RECEIVER_ID);
    return ();
}
