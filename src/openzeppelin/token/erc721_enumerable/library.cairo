# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (token/erc721_enumerable/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import (
    Uint256, uint256_lt, uint256_eq, uint256_check
)

from openzeppelin.introspection.ERC165 import ERC165
from openzeppelin.utils.constants import IERC721_ENUMERABLE_ID

from openzeppelin.security.safemath import SafeUint256

from openzeppelin.token.erc721.library import ERC721

#
# Storage
#

@storage_var
func ERC721_Enumerable_all_tokens_len() -> (res: Uint256):
end

@storage_var
func ERC721_Enumerable_all_tokens(index: Uint256) -> (token_id: Uint256):
end

@storage_var
func ERC721_Enumerable_all_tokens_index(token_id: Uint256) -> (index: Uint256):
end

@storage_var
func ERC721_Enumerable_owned_tokens(owner: felt, index: Uint256) -> (token_id: Uint256):
end

@storage_var
func ERC721_Enumerable_owned_tokens_index(token_id: Uint256) -> (index: Uint256):
end


namespace ERC721_Enumerable:

    #
    # Constructor
    #

    func initializer{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        ERC165.register_interface(IERC721_ENUMERABLE_ID)
        return ()
    end

    #
    # Getters
    #

    func total_supply{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }() -> (total_supply: Uint256):
        let (total_supply) = ERC721_Enumerable_all_tokens_len.read()
        return (total_supply)
    end


    func token_by_index{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(index: Uint256) -> (token_id: Uint256):
        alloc_locals
        uint256_check(index)
        # Ensures index argument is less than total_supply
        let (len: Uint256) = ERC721_Enumerable.total_supply()
        let (is_lt) = uint256_lt(index, len)
        with_attr error_message("ERC721_Enumerable: global index out of bounds"):
            assert is_lt = TRUE
        end

        let (token_id: Uint256) = ERC721_Enumerable_all_tokens.read(index)
        return (token_id)
    end

    func token_of_owner_by_index{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(owner: felt, index: Uint256) -> (token_id: Uint256):
        alloc_locals
        uint256_check(index)
        # Ensures index argument is less than owner's balance
        let (len: Uint256) = ERC721.balance_of(owner)
        let (is_lt) = uint256_lt(index, len)
        with_attr error_message("ERC721_Enumerable: owner index out of bounds"):
            assert is_lt = TRUE
        end

        let (token_id: Uint256) = ERC721_Enumerable_owned_tokens.read(owner, index)
        return (token_id)
    end

    #
    # Externals
    #
    func transfer_from{
            pedersen_ptr: HashBuiltin*,
            syscall_ptr: felt*,
            range_check_ptr
        }(from_: felt, to: felt, token_id: Uint256):
        _remove_token_from_owner_enumeration(from_, token_id)
        _add_token_to_owner_enumeration(to, token_id)
        ERC721.transfer_from(from_, to, token_id)
        return ()
    end

    func safe_transfer_from{
            pedersen_ptr: HashBuiltin*,
            syscall_ptr: felt*,
            range_check_ptr
        }(
            from_: felt,
            to: felt,
            token_id: Uint256,
            data_len: felt,
            data: felt*
        ):
        _remove_token_from_owner_enumeration(from_, token_id)
        _add_token_to_owner_enumeration(to, token_id)
        ERC721.safe_transfer_from(from_, to, token_id, data_len, data)
        return ()
    end

    #
    # Internals
    #

    func _mint{
            pedersen_ptr: HashBuiltin*,
            syscall_ptr: felt*,
            range_check_ptr
        }(to: felt, token_id: Uint256):
        _add_token_to_all_tokens_enumeration(token_id)
        _add_token_to_owner_enumeration(to, token_id)
        ERC721._mint(to, token_id)
        return ()
    end

    func _burn{
            pedersen_ptr: HashBuiltin*,
            syscall_ptr: felt*,
            range_check_ptr
        }(token_id: Uint256):
        let (from_) = ERC721.owner_of(token_id)
        _remove_token_from_owner_enumeration(from_, token_id)
        _remove_token_from_all_tokens_enumeration(token_id)
        ERC721._burn(token_id)
        return ()
    end

end

#
# Private
#

func _add_token_to_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(token_id: Uint256):
    let (supply: Uint256) = ERC721_Enumerable_all_tokens_len.read()
    ERC721_Enumerable_all_tokens.write(supply, token_id)
    ERC721_Enumerable_all_tokens_index.write(token_id, supply)

    let (new_supply: Uint256) = SafeUint256.add(supply, Uint256(1, 0))
    ERC721_Enumerable_all_tokens_len.write(new_supply)
    return ()
end

func _remove_token_from_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (supply: Uint256) = ERC721_Enumerable_all_tokens_len.read()
    let (last_token_index: Uint256) = SafeUint256.sub_le(supply, Uint256(1, 0))
    let (token_index: Uint256) = ERC721_Enumerable_all_tokens_index.read(token_id)
    let (last_token_id: Uint256) = ERC721_Enumerable_all_tokens.read(last_token_index)

    ERC721_Enumerable_all_tokens.write(last_token_index, Uint256(0, 0))
    ERC721_Enumerable_all_tokens_index.write(token_id, Uint256(0, 0))
    ERC721_Enumerable_all_tokens_len.write(last_token_index)

    let (is_equal) = uint256_eq(last_token_index, token_index)
    if is_equal == FALSE:
        ERC721_Enumerable_all_tokens_index.write(last_token_id, token_index)
        ERC721_Enumerable_all_tokens.write(token_index, last_token_id)
        return ()
    end
    return ()
end


func _add_token_to_owner_enumeration{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(to: felt, token_id: Uint256):
    let (length: Uint256) = ERC721.balance_of(to)
    ERC721_Enumerable_owned_tokens.write(to, length, token_id)
    ERC721_Enumerable_owned_tokens_index.write(token_id, length)
    return ()
end


func _remove_token_from_owner_enumeration{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(from_: felt, token_id: Uint256):
    alloc_locals
    let (last_token_index: Uint256) = ERC721.balance_of(from_)
    # the index starts at zero therefore the user's last token index is their balance minus one
    let (last_token_index) = SafeUint256.sub_le(last_token_index, Uint256(1, 0))
    let (token_index: Uint256) = ERC721_Enumerable_owned_tokens_index.read(token_id)

    # If index is last, we can just set the return values to zero
    let (is_equal) = uint256_eq(token_index, last_token_index)
    if is_equal == TRUE:
        ERC721_Enumerable_owned_tokens_index.write(token_id, Uint256(0, 0))
        ERC721_Enumerable_owned_tokens.write(from_, last_token_index, Uint256(0, 0))
        return ()
    end

    # If index is not last, reposition owner's last token to the removed token's index
    let (last_token_id: Uint256) = ERC721_Enumerable_owned_tokens.read(from_, last_token_index)
    ERC721_Enumerable_owned_tokens.write(from_, token_index, last_token_id)
    ERC721_Enumerable_owned_tokens_index.write(last_token_id, token_index)
    return ()
end
