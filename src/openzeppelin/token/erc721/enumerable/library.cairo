// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0b (token/erc721/enumerable/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_lt, uint256_eq, uint256_check

from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc721.library import ERC721
from openzeppelin.utils.constants.library import IERC721_ENUMERABLE_ID

//
// Storage
//

@storage_var
func ERC721Enumerable_all_tokens_len() -> (total_supply: Uint256) {
}

@storage_var
func ERC721Enumerable_all_tokens(index: Uint256) -> (token_id: Uint256) {
}

@storage_var
func ERC721Enumerable_all_tokens_index(token_id: Uint256) -> (index: Uint256) {
}

@storage_var
func ERC721Enumerable_owned_tokens(owner: felt, index: Uint256) -> (token_id: Uint256) {
}

@storage_var
func ERC721Enumerable_owned_tokens_index(token_id: Uint256) -> (index: Uint256) {
}

namespace ERC721Enumerable {
    //
    // Constructor
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        ERC165.register_interface(IERC721_ENUMERABLE_ID);
        return ();
    }

    //
    // Getters
    //

    func total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        total_supply: Uint256
    ) {
        return ERC721Enumerable_all_tokens_len.read();
    }

    func token_by_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: Uint256
    ) -> (token_id: Uint256) {
        alloc_locals;
        uint256_check(index);
        // Ensures index argument is less than total_supply
        let (len: Uint256) = ERC721Enumerable.total_supply();
        let (is_lt) = uint256_lt(index, len);
        with_attr error_message("ERC721Enumerable: global index out of bounds") {
            assert is_lt = TRUE;
        }

        return ERC721Enumerable_all_tokens.read(index);
    }

    func token_of_owner_by_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, index: Uint256
    ) -> (token_id: Uint256) {
        alloc_locals;
        uint256_check(index);
        // Ensures index argument is less than owner's balance
        let (len: Uint256) = ERC721.balance_of(owner);
        let (is_lt) = uint256_lt(index, len);
        with_attr error_message("ERC721Enumerable: owner index out of bounds") {
            assert is_lt = TRUE;
        }

        return ERC721Enumerable_owned_tokens.read(owner, index);
    }

    //
    // Externals
    //
    func transfer_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256
    ) {
        _remove_token_from_owner_enumeration(from_, token_id);
        _add_token_to_owner_enumeration(to, token_id);
        ERC721.transfer_from(from_, to, token_id);
        return ();
    }

    func safe_transfer_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*
    ) {
        _remove_token_from_owner_enumeration(from_, token_id);
        _add_token_to_owner_enumeration(to, token_id);
        ERC721.safe_transfer_from(from_, to, token_id, data_len, data);
        return ();
    }

    //
    // Internals
    //

    func _mint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        to: felt, token_id: Uint256
    ) {
        _add_token_to_all_tokens_enumeration(token_id);
        _add_token_to_owner_enumeration(to, token_id);
        ERC721._mint(to, token_id);
        return ();
    }

    func _burn{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(token_id: Uint256) {
        let (from_) = ERC721.owner_of(token_id);
        _remove_token_from_owner_enumeration(from_, token_id);
        _remove_token_from_all_tokens_enumeration(token_id);
        ERC721._burn(token_id);
        return ();
    }
}

//
// Private
//

func _add_token_to_all_tokens_enumeration{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}(token_id: Uint256) {
    let (supply: Uint256) = ERC721Enumerable_all_tokens_len.read();
    ERC721Enumerable_all_tokens.write(supply, token_id);
    ERC721Enumerable_all_tokens_index.write(token_id, supply);

    let (new_supply: Uint256) = SafeUint256.add(supply, Uint256(1, 0));
    ERC721Enumerable_all_tokens_len.write(new_supply);
    return ();
}

func _remove_token_from_all_tokens_enumeration{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}(token_id: Uint256) {
    alloc_locals;
    let (supply: Uint256) = ERC721Enumerable_all_tokens_len.read();
    let (last_token_index: Uint256) = SafeUint256.sub_le(supply, Uint256(1, 0));
    let (token_index: Uint256) = ERC721Enumerable_all_tokens_index.read(token_id);
    let (last_token_id: Uint256) = ERC721Enumerable_all_tokens.read(last_token_index);

    ERC721Enumerable_all_tokens.write(last_token_index, Uint256(0, 0));
    ERC721Enumerable_all_tokens_index.write(token_id, Uint256(0, 0));
    ERC721Enumerable_all_tokens_len.write(last_token_index);

    let (is_equal) = uint256_eq(last_token_index, token_index);
    if (is_equal == FALSE) {
        ERC721Enumerable_all_tokens_index.write(last_token_id, token_index);
        ERC721Enumerable_all_tokens.write(token_index, last_token_id);
        return ();
    }
    return ();
}

func _add_token_to_owner_enumeration{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}(to: felt, token_id: Uint256) {
    let (length: Uint256) = ERC721.balance_of(to);
    ERC721Enumerable_owned_tokens.write(to, length, token_id);
    ERC721Enumerable_owned_tokens_index.write(token_id, length);
    return ();
}

func _remove_token_from_owner_enumeration{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}(from_: felt, token_id: Uint256) {
    alloc_locals;
    let (last_token_index: Uint256) = ERC721.balance_of(from_);
    // the index starts at zero therefore the user's last token index is their balance minus one
    let (last_token_index) = SafeUint256.sub_le(last_token_index, Uint256(1, 0));
    let (token_index: Uint256) = ERC721Enumerable_owned_tokens_index.read(token_id);

    // If index is last, we can just set the return values to zero
    let (is_equal) = uint256_eq(token_index, last_token_index);
    if (is_equal == TRUE) {
        ERC721Enumerable_owned_tokens_index.write(token_id, Uint256(0, 0));
        ERC721Enumerable_owned_tokens.write(from_, last_token_index, Uint256(0, 0));
        return ();
    }

    // If index is not last, reposition owner's last token to the removed token's index
    let (last_token_id: Uint256) = ERC721Enumerable_owned_tokens.read(from_, last_token_index);
    ERC721Enumerable_owned_tokens.write(from_, token_index, last_token_id);
    ERC721Enumerable_owned_tokens_index.write(last_token_id, token_index);
    return ();
}
