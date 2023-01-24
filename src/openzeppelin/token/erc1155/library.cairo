// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (token/erc1155/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.bool import TRUE

from openzeppelin.introspection.erc165.IERC165 import IERC165
from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.token.erc1155.IERC1155Receiver import IERC1155Receiver
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.utils.constants.library import (
    IERC1155_ID,
    IERC1155_METADATA_ID,
    IERC1155_RECEIVER_ID,
    IACCOUNT_ID,
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR,
)

//
// Events
//

@event
func TransferSingle(
    operator: felt,
    from_: felt,
    to: felt,
    id: Uint256,
    value: Uint256
) {
}

@event
func TransferBatch(
    operator: felt,
    from_: felt,
    to: felt,
    ids_len: felt,
    ids: Uint256*,
    values_len: felt,
    values: Uint256*,
) {
}

@event
func ApprovalForAll(account: felt, operator: felt, approved: felt) {
}

@event
func URI(value: felt, id: Uint256) {
}

//
// Storage
//

@storage_var
func ERC1155_balances(id: Uint256, account: felt) -> (balance: Uint256) {
}

@storage_var
func ERC1155_operator_approvals(account: felt, operator: felt) -> (approved: felt) {
}

@storage_var
func ERC1155_uri() -> (uri: felt) {
}

namespace ERC1155 {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(uri: felt) {
        _set_uri(uri);
        ERC165.register_interface(IERC1155_ID);
        ERC165.register_interface(IERC1155_METADATA_ID);
        return ();
    }

    //
    // Modifiers
    //

    func assert_owner_or_approved{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt
    ) {
        let (caller) = get_caller_address();
        if (caller == owner) {
            return ();
        }
        let (approved) = ERC1155.is_approved_for_all(owner, caller);
        with_attr error_message("ERC1155: caller is not owner nor approved") {
            assert approved = TRUE;
        }
        return ();
    }

    //
    // Getters
    //

    // This implementation returns the same URI for *all* token types. It relies
    // on the token type ID substitution mechanism
    // https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
    //
    // Clients calling this function must replace the `\{id\}` substring with the
    // actual token type ID.
    func uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: Uint256) -> (
        uri: felt
    ) {
        return ERC1155_uri.read();
    }

    func balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, id: Uint256
    ) -> (balance: Uint256) {
        with_attr error_message("ERC1155: address zero is not a valid owner") {
            assert_not_zero(account);
        }
        _check_id(id);
        return ERC1155_balances.read(id, account);
    }

    func balance_of_batch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        accounts_len: felt, accounts: felt*, ids_len: felt, ids: Uint256*
    ) -> (balances_len: felt, balances: Uint256*) {
        alloc_locals;
        // Check args are equal length arrays
        with_attr error_message("ERC1155: accounts and ids length mismatch") {
            assert ids_len = accounts_len;
        }
        // Allocate memory
        let (local balances: Uint256*) = alloc();
        // Call iterator
        _balance_of_batch_iter(accounts_len, accounts, ids, balances);
        return (accounts_len, balances);
    }

    func is_approved_for_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, operator: felt
    ) -> (approved: felt) {
        return ERC1155_operator_approvals.read(account, operator);
    }

    //
    // Externals
    //

    func set_approval_for_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        operator: felt, approved: felt
    ) {
        let (caller) = get_caller_address();
        with_attr error_message("ERC1155: cannot approve from the zero address") {
            assert_not_zero(caller);
        }
        _set_approval_for_all(caller, operator, approved);
        return ();
    }

    func safe_transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, to: felt, id: Uint256, value: Uint256, data_len: felt, data: felt*
    ) {
        let (caller) = get_caller_address();
        with_attr error_message("ERC1155: cannot call transfer from the zero address") {
            assert_not_zero(caller);
        }
        assert_owner_or_approved(from_);
        _safe_transfer_from(from_, to, id, value, data_len, data);
        return ();
    }

    func safe_batch_transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        to: felt,
        ids_len: felt,
        ids: Uint256*,
        values_len: felt,
        values: Uint256*,
        data_len: felt,
        data: felt*,
    ) {
        let (caller) = get_caller_address();
        with_attr error_message("ERC1155: cannot call transfer from the zero address") {
            assert_not_zero(caller);
        }
        assert_owner_or_approved(from_);
        _safe_batch_transfer_from(from_, to, ids_len, ids, values_len, values, data_len, data);
        return ();
    }

    //
    // Internals
    //

    func _safe_transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, to: felt, id: Uint256, value: Uint256, data_len: felt, data: felt*
    ) {
        alloc_locals;
        // Validate input
        with_attr error_message("ERC1155: transfer to the zero address") {
            assert_not_zero(to);
        }
        _check_id(id);
        _check_value(value);

        // Deduct from sender
        let (from_balance: Uint256) = ERC1155_balances.read(id, from_);
        with_attr error_message("ERC1155: insufficient balance for transfer") {
            let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, value);
        }
        ERC1155_balances.write(id, from_, new_balance);

        // Add to receiver
        _add_to_receiver(id, value, to);

        // Emit events and check
        let (operator) = get_caller_address();
        TransferSingle.emit(operator, from_, to, id, value);

        _do_safe_transfer_acceptance_check(operator, from_, to, id, value, data_len, data);
        return ();
    }

    func _safe_batch_transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        to: felt,
        ids_len: felt,
        ids: Uint256*,
        values_len: felt,
        values: Uint256*,
        data_len: felt,
        data: felt*,
    ) {
        alloc_locals;
        // Check args
        with_attr error_message("ERC1155: transfer to the zero address") {
            assert_not_zero(to);
        }
        with_attr error_message("ERC1155: ids and values length mismatch") {
            assert ids_len = values_len;
        }
        // Recursive call
        _safe_batch_transfer_from_iter(from_, to, ids_len, ids, values);

        // Emit events and check
        let (operator) = get_caller_address();
        TransferBatch.emit(operator, from_, to, ids_len, ids, values_len, values);

        _do_safe_batch_transfer_acceptance_check(
            operator, from_, to, ids_len, ids, values_len, values, data_len, data
        );
        return ();
    }

    func _mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        to: felt, id: Uint256, value: Uint256, data_len: felt, data: felt*
    ) {
        // Validate input
        with_attr error_message("ERC1155: mint to the zero address") {
            assert_not_zero(to);
        }
        _check_id(id);
        _check_value(value);

        // Add to minter, check for overflow
        _add_to_receiver(id, value, to);

        // Emit events and check
        let (operator) = get_caller_address();
        TransferSingle.emit(operator=operator, from_=0, to=to, id=id, value=value);
        _do_safe_transfer_acceptance_check(
            operator=operator, from_=0, to=to, id=id, value=value, data_len=data_len, data=data
        );
        return ();
    }

    func _mint_batch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        to: felt,
        ids_len: felt,
        ids: Uint256*,
        values_len: felt,
        values: Uint256*,
        data_len: felt,
        data: felt*,
    ) {
        alloc_locals;
        // Cannot mint to zero address
        with_attr error_message("ERC1155: mint to the zero address") {
            assert_not_zero(to);
        }
        // Check args are equal length arrays
        with_attr error_message("ERC1155: ids and values length mismatch") {
            assert ids_len = values_len;
        }

        // Recursive call
        _mint_batch_iter(to, ids_len, ids, values);

        // Emit events and check
        let (operator) = get_caller_address();
        TransferBatch.emit(
            operator=operator,
            from_=0,
            to=to,
            ids_len=ids_len,
            ids=ids,
            values_len=values_len,
            values=values,
        );
        _do_safe_batch_transfer_acceptance_check(
            operator=operator,
            from_=0,
            to=to,
            ids_len=ids_len,
            ids=ids,
            values_len=values_len,
            values=values,
            data_len=data_len,
            data=data,
        );
        return ();
    }

    func _burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, id: Uint256, value: Uint256
    ) {
        alloc_locals;
        // Validate input
        with_attr error_message("ERC1155: burn from the zero address") {
            assert_not_zero(from_);
        }
        _check_id(id);
        _check_value(value);

        // Deduct from burner
        let (from_balance: Uint256) = ERC1155_balances.read(id, from_);
        with_attr error_message("ERC1155: burn value exceeds balance") {
            let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, value);
        }

        ERC1155_balances.write(id, from_, new_balance);

        let (operator) = get_caller_address();
        TransferSingle.emit(operator=operator, from_=from_, to=0, id=id, value=value);
        return ();
    }

    func _burn_batch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, ids_len: felt, ids: Uint256*, values_len: felt, values: Uint256*
    ) {
        alloc_locals;
        with_attr error_message("ERC1155: burn from the zero address") {
            assert_not_zero(from_);
        }
        with_attr error_message("ERC1155: ids and values length mismatch") {
            assert ids_len = values_len;
        }

        // Recursive call
        _burn_batch_iter(from_, ids_len, ids, values);
        let (operator) = get_caller_address();
        TransferBatch.emit(
            operator=operator,
            from_=from_,
            to=0,
            ids_len=ids_len,
            ids=ids,
            values_len=values_len,
            values=values,
        );
        return ();
    }

    func _set_approval_for_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, operator: felt, approved: felt
    ) {
        // check approved is bool
        with_attr error_message("ERC1155: approval is not boolean") {
            assert approved * (approved - 1) = 0;
        }

        // caller/owner already checked non-0
        with_attr error_message("ERC1155: setting approval status for zero address") {
            assert_not_zero(operator);
        }

        with_attr error_message("ERC1155: setting approval status for self") {
            assert_not_equal(owner, operator);
        }

        ERC1155_operator_approvals.write(owner, operator, approved);
        ApprovalForAll.emit(owner, operator, approved);
        return ();
    }

    func _set_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(uri: felt) {
        ERC1155_uri.write(uri);
        return ();
    }
}

//
// Private
//

func _do_safe_transfer_acceptance_check{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    operator: felt, from_: felt, to: felt, id: Uint256, value: Uint256, data_len: felt, data: felt*
) {
    // Confirm supports IERC1155receiver interface
    let (is_supported) = IERC165.supportsInterface(to, IERC1155_RECEIVER_ID);
    if (is_supported == TRUE) {
        let (selector) = IERC1155Receiver.onERC1155Received(
            to, operator, from_, id, value, data_len, data
        );

        // Confirm onERC1155Recieved selector returned
        with_attr error_message("ERC1155: ERC1155Receiver rejected tokens") {
            assert selector = ON_ERC1155_RECEIVED_SELECTOR;
        }
        return ();
    }

    // Alternatively confirm account
    let (is_account) = IERC165.supportsInterface(to, IACCOUNT_ID);
    with_attr error_message("ERC1155: transfer to non-ERC1155Receiver implementer") {
        assert is_account = TRUE;
    }
    return ();
}

func _do_safe_batch_transfer_acceptance_check{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    operator: felt,
    from_: felt,
    to: felt,
    ids_len: felt,
    ids: Uint256*,
    values_len: felt,
    values: Uint256*,
    data_len: felt,
    data: felt*,
) {
    // Confirm supports IERC1155receiver interface
    let (is_supported) = IERC165.supportsInterface(to, IERC1155_RECEIVER_ID);
    if (is_supported == TRUE) {
        let (selector) = IERC1155Receiver.onERC1155BatchReceived(
            contract_address=to,
            operator=operator,
            from_=from_,
            ids_len=ids_len,
            ids=ids,
            values_len=values_len,
            values=values,
            data_len=data_len,
            data=data,
        );
        // Confirm onBatchERC1155Recieved selector returned
        with_attr error_message("ERC1155: ERC1155Receiver rejected tokens") {
            assert selector = ON_ERC1155_BATCH_RECEIVED_SELECTOR;
        }
        return ();
    }

    // Alternatively confirm account
    let (is_account) = IERC165.supportsInterface(to, IACCOUNT_ID);
    with_attr error_message("ERC1155: transfer to non-ERC1155Receiver implementer") {
        assert is_account = TRUE;
    }
    return ();
}

func _balance_of_batch_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    len: felt, accounts: felt*, ids: Uint256*, batch_balances: Uint256*
) {
    if (len == 0) {
        return ();
    }
    // Read current entries
    let id: Uint256 = [ids];
    _check_id(id);
    let account: felt = [accounts];

    // Get balance
    let (balance: Uint256) = ERC1155.balance_of(account, id);
    assert [batch_balances] = balance;
    return _balance_of_batch_iter(
        len - 1, accounts + 1, ids + Uint256.SIZE, batch_balances + Uint256.SIZE
    );
}

func _safe_batch_transfer_from_iter{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(from_: felt, to: felt, len: felt, ids: Uint256*, values: Uint256*) {
    // Base case
    alloc_locals;
    if (len == 0) {
        return ();
    }

    // Read current entries, perform Uint256 checks
    let id = [ids];
    let value = [values];
    _check_id(id);
    _check_value(value);

    // deduct from sender
    let (from_balance: Uint256) = ERC1155_balances.read(id, from_);
    with_attr error_message("ERC1155: insufficient balance for transfer") {
        let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, value);
    }
    ERC1155_balances.write(id, from_, new_balance);

    _add_to_receiver(id, value, to);

    // Recursive call
    return _safe_batch_transfer_from_iter(
        from_, to, len - 1, ids + Uint256.SIZE, values + Uint256.SIZE
    );
}

func _mint_batch_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, len: felt, ids: Uint256*, values: Uint256*
) {
    // Base case
    alloc_locals;
    if (len == 0) {
        return ();
    }

    // Read current entries
    let id: Uint256 = [ids];
    let value: Uint256 = [values];
    _check_id(id);
    _check_value(value);

    _add_to_receiver(id, value, to);

    // Recursive call
    return _mint_batch_iter(to, len - 1, ids + Uint256.SIZE, values + Uint256.SIZE);
}

func _burn_batch_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, len: felt, ids: Uint256*, values: Uint256*
) {
    // Base case
    alloc_locals;
    if (len == 0) {
        return ();
    }

    // Read current entries
    let id: Uint256 = [ids];
    let value: Uint256 = [values];
    _check_id(id);
    _check_value(value);

    // Deduct from burner
    let (from_balance: Uint256) = ERC1155_balances.read(id, from_);
    with_attr error_message("ERC1155: burn value exceeds balance") {
        let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, value);
    }
    ERC1155_balances.write(id, from_, new_balance);

    // Recursive call
    return _burn_batch_iter(from_, len - 1, ids + Uint256.SIZE, values + Uint256.SIZE);
}

func _add_to_receiver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    id: Uint256, value: Uint256, receiver: felt
) {
    let (receiver_balance: Uint256) = ERC1155_balances.read(id, receiver);
    with_attr error_message("ERC1155: balance overflow") {
        let (new_balance: Uint256) = SafeUint256.add(receiver_balance, value);
    }
    ERC1155_balances.write(id, receiver, new_balance);
    return ();
}

func _check_id{range_check_ptr}(id: Uint256) {
    with_attr error_message("ERC1155: token_id is not a valid Uint256") {
        uint256_check(id);
    }
    return ();
}

func _check_value{range_check_ptr}(value: Uint256) {
    with_attr error_message("ERC1155: value is not a valid Uint256") {
        uint256_check(value);
    }
    return ();
}
