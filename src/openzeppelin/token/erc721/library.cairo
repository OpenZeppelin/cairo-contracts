// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (token/erc721/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_check

from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.introspection.erc165.IERC165 import IERC165
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc721.IERC721Receiver import IERC721Receiver
from openzeppelin.utils.constants.library import (
    IERC721_ID,
    IERC721_METADATA_ID,
    IERC721_RECEIVER_ID,
    IACCOUNT_ID,
)

//
// Events
//

@event
func Transfer(from_: felt, to: felt, tokenId: Uint256) {
}

@event
func Approval(owner: felt, approved: felt, tokenId: Uint256) {
}

@event
func ApprovalForAll(owner: felt, operator: felt, approved: felt) {
}

//
// Storage
//

@storage_var
func ERC721_name() -> (name: felt) {
}

@storage_var
func ERC721_symbol() -> (symbol: felt) {
}

@storage_var
func ERC721_owners(token_id: Uint256) -> (owner: felt) {
}

@storage_var
func ERC721_balances(account: felt) -> (balance: Uint256) {
}

@storage_var
func ERC721_token_approvals(token_id: Uint256) -> (approved: felt) {
}

@storage_var
func ERC721_operator_approvals(owner: felt, operator: felt) -> (is_approved: felt) {
}

@storage_var
func ERC721_token_uri(token_id: Uint256) -> (token_uri: felt) {
}

namespace ERC721 {
    //
    // Constructor
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        name: felt, symbol: felt
    ) {
        ERC721_name.write(name);
        ERC721_symbol.write(symbol);
        ERC165.register_interface(IERC721_ID);
        ERC165.register_interface(IERC721_METADATA_ID);
        return ();
    }

    //
    // Getters
    //

    func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
        return ERC721_name.read();
    }

    func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        symbol: felt
    ) {
        return ERC721_symbol.read();
    }

    func balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt
    ) -> (balance: Uint256) {
        with_attr error_message("ERC721: balance query for the zero address") {
            assert_not_zero(owner);
        }
        return ERC721_balances.read(owner);
    }

    func owner_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (owner: felt) {
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        let (owner) = ERC721_owners.read(token_id);
        with_attr error_message("ERC721: owner query for nonexistent token") {
            assert_not_zero(owner);
        }
        return (owner=owner);
    }

    func get_approved{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (approved: felt) {
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        let exists = _exists(token_id);
        with_attr error_message("ERC721: approved query for nonexistent token") {
            assert exists = TRUE;
        }

        return ERC721_token_approvals.read(token_id);
    }

    func is_approved_for_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, operator: felt
    ) -> (is_approved: felt) {
        return ERC721_operator_approvals.read(owner, operator);
    }

    func token_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (token_uri: felt) {
        let exists = _exists(token_id);
        with_attr error_message("ERC721_Metadata: URI query for nonexistent token") {
            assert exists = TRUE;
        }

        // if tokenURI is not set, it will return 0
        return ERC721_token_uri.read(token_id);
    }

    //
    // Externals
    //

    func approve{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        to: felt, token_id: Uint256
    ) {
        with_attr error_mesage("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }

        // Checks caller is not zero address
        let (caller) = get_caller_address();
        with_attr error_message("ERC721: cannot approve from the zero address") {
            assert_not_zero(caller);
        }

        // Ensures 'owner' does not equal 'to'
        let (owner) = ERC721_owners.read(token_id);
        with_attr error_message("ERC721: approval to current owner") {
            assert_not_equal(owner, to);
        }

        // Checks that either caller equals owner or
        // caller isApprovedForAll on behalf of owner
        if (caller == owner) {
            _approve(to, token_id);
            return ();
        } else {
            let (is_approved) = ERC721_operator_approvals.read(owner, caller);
            with_attr error_message("ERC721: approve caller is not owner nor approved for all") {
                assert_not_zero(is_approved);
            }
            _approve(to, token_id);
            return ();
        }
    }

    func set_approval_for_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        operator: felt, approved: felt
    ) {
        // Ensures caller is neither zero address nor operator
        let (caller) = get_caller_address();
        with_attr error_message("ERC721: either the caller or operator is the zero address") {
            assert_not_zero(caller * operator);
        }
        // note this pattern as we'll frequently use it:
        //   instead of making an `assert_not_zero` call for each address
        //   we can always briefly write `assert_not_zero(a0 * a1 * ... * aN)`.
        //   This is because these addresses are field elements,
        //   meaning that a*0==0 for all a in the field,
        //   and a*b==0 implies that at least one of a,b are zero in the field
        with_attr error_message("ERC721: approve to caller") {
            assert_not_equal(caller, operator);
        }

        // Make sure `approved` is a boolean (0 or 1)
        with_attr error_message("ERC721: approved is not a Cairo boolean") {
            assert approved * (1 - approved) = 0;
        }

        ERC721_operator_approvals.write(owner=caller, operator=operator, value=approved);
        ApprovalForAll.emit(caller, operator, approved);
        return ();
    }

    func transfer_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256
    ) {
        alloc_locals;
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        let (caller) = get_caller_address();
        let is_approved = _is_approved_or_owner(caller, token_id);
        with_attr error_message(
                "ERC721: either is not approved or the caller is the zero address") {
            assert_not_zero(caller * is_approved);
        }
        // Note that if either `is_approved` or `caller` equals `0`,
        // then this method should fail.
        // The `caller` address and `is_approved` boolean are both field elements
        // meaning that a*0==0 for all a in the field,
        // therefore a*b==0 implies that at least one of a,b is zero in the field

        _transfer(from_, to, token_id);
        return ();
    }

    func safe_transfer_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*
    ) {
        alloc_locals;
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        let (caller) = get_caller_address();
        let is_approved = _is_approved_or_owner(caller, token_id);
        with_attr error_message(
                "ERC721: either is not approved or the caller is the zero address") {
            assert_not_zero(caller * is_approved);
        }
        // Note that if either `is_approved` or `caller` equals `0`,
        // then this method should fail.
        // The `caller` address and `is_approved` boolean are both field elements
        // meaning that a*0==0 for all a in the field,
        // therefore a*b==0 implies that at least one of a,b is zero in the field

        _safe_transfer(from_, to, token_id, data_len, data);
        return ();
    }

    //
    // Internals
    //

    func assert_only_token_owner{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        token_id: Uint256
    ) {
        uint256_check(token_id);
        let (caller) = get_caller_address();
        let (owner) = owner_of(token_id);
        // Note `owner_of` checks that the owner is not the zero address
        with_attr error_message("ERC721: caller is not the token owner") {
            assert caller = owner;
        }
        return ();
    }

    func _is_approved_or_owner{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        spender: felt, token_id: Uint256
    ) -> felt {
        alloc_locals;

        let exists = _exists(token_id);
        with_attr error_message("ERC721: token id does not exist") {
            assert exists = TRUE;
        }

        let (owner) = owner_of(token_id);
        if (owner == spender) {
            return TRUE;
        }

        let (approved_addr) = get_approved(token_id);
        if (approved_addr == spender) {
            return TRUE;
        }

        let (is_operator) = is_approved_for_all(owner, spender);
        if (is_operator == TRUE) {
            return TRUE;
        }

        return FALSE;
    }

    func _exists{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> felt {
        let (exists) = ERC721_owners.read(token_id);
        if (exists == FALSE) {
            return FALSE;
        }

        return TRUE;
    }

    func _approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        to: felt, token_id: Uint256
    ) {
        ERC721_token_approvals.write(token_id, to);
        let (owner) = owner_of(token_id);
        Approval.emit(owner, to, token_id);
        return ();
    }

    func _transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256
    ) {
        // ownerOf ensures 'from_' is not the zero address
        let (owner) = owner_of(token_id);
        with_attr error_message("ERC721: transfer from incorrect owner") {
            assert owner = from_;
        }

        with_attr error_message("ERC721: cannot transfer to the zero address") {
            assert_not_zero(to);
        }

        // Clear approvals
        _approve(0, token_id);

        // Decrease owner balance
        let (owner_bal) = ERC721_balances.read(from_);
        let (new_balance: Uint256) = SafeUint256.sub_le(owner_bal, Uint256(1, 0));
        ERC721_balances.write(from_, new_balance);

        // Increase receiver balance
        let (receiver_bal) = ERC721_balances.read(to);
        let (new_balance: Uint256) = SafeUint256.add(receiver_bal, Uint256(1, 0));
        ERC721_balances.write(to, new_balance);

        // Update token_id owner
        ERC721_owners.write(token_id, to);
        Transfer.emit(from_, to, token_id);
        return ();
    }

    func _safe_transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*
    ) {
        _transfer(from_, to, token_id);

        let (success) = _check_onERC721Received(from_, to, token_id, data_len, data);
        with_attr error_message("ERC721: transfer to non ERC721Receiver implementer") {
            assert_not_zero(success);
        }
        return ();
    }

    func _mint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        to: felt, token_id: Uint256
    ) {
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        with_attr error_message("ERC721: cannot mint to the zero address") {
            assert_not_zero(to);
        }

        // Ensures token_id is unique
        let exists = _exists(token_id);
        with_attr error_message("ERC721: token already minted") {
            assert exists = FALSE;
        }

        let (balance: Uint256) = ERC721_balances.read(to);
        let (new_balance: Uint256) = SafeUint256.add(balance, Uint256(1, 0));
        ERC721_balances.write(to, new_balance);
        ERC721_owners.write(token_id, to);
        Transfer.emit(0, to, token_id);
        return ();
    }

    func _safe_mint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        to: felt, token_id: Uint256, data_len: felt, data: felt*
    ) {
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        _mint(to, token_id);

        let (success) = _check_onERC721Received(0, to, token_id, data_len, data);
        with_attr error_message("ERC721: transfer to non ERC721Receiver implementer") {
            assert_not_zero(success);
        }
        return ();
    }

    func _burn{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(token_id: Uint256) {
        alloc_locals;
        with_attr error_message("ERC721: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        let (owner) = owner_of(token_id);

        // Clear approvals
        _approve(0, token_id);

        // Decrease owner balance
        let (balance: Uint256) = ERC721_balances.read(owner);
        let (new_balance: Uint256) = SafeUint256.sub_le(balance, Uint256(1, 0));
        ERC721_balances.write(owner, new_balance);

        // Delete owner
        ERC721_owners.write(token_id, 0);
        Transfer.emit(owner, 0, token_id);
        return ();
    }

    func _set_token_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256, token_uri: felt
    ) {
        uint256_check(token_id);
        let exists = _exists(token_id);
        with_attr error_message("ERC721_Metadata: set token URI for nonexistent token") {
            assert exists = TRUE;
        }

        ERC721_token_uri.write(token_id, token_uri);
        return ();
    }
}

//
// Private
//

func _check_onERC721Received{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*
) -> (success: felt) {
    let (caller) = get_caller_address();
    let (is_supported) = IERC165.supportsInterface(to, IERC721_RECEIVER_ID);
    if (is_supported == TRUE) {
        let (selector) = IERC721Receiver.onERC721Received(
            to, caller, from_, token_id, data_len, data
        );

        with_attr error_message("ERC721: transfer to non ERC721Receiver implementer") {
            assert selector = IERC721_RECEIVER_ID;
        }
        return (success=TRUE);
    }

    let (is_account) = IERC165.supportsInterface(to, IACCOUNT_ID);
    return (success=is_account);
}
