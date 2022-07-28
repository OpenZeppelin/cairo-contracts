# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.1 (token/erc1155/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.bool import TRUE

from openzeppelin.introspection.erc165.IERC165 import IERC165
from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.token.erc1155.IERC1155Receiver import IERC1155_Receiver
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.utils.constants.library import (
    IERC1155_ID,
    IERC1155_METADATA_ID,
    IERC1155_RECEIVER_ID,
    IACCOUNT_ID,
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR
)


#
# Events
#

@event
func TransferSingle(
    operator: felt,
    from_: felt,
    to: felt,
    id: Uint256,
    value: Uint256
):
end

@event
func TransferBatch(
    operator: felt,
    from_: felt,
    to: felt,
    ids_len: felt,
    ids: Uint256*,
    values_len: felt,
    values: Uint256*
):
end

@event
func ApprovalForAll(account: felt, operator: felt, approved: felt):
end

@event
func URI(value_len: felt, value: felt*, id: Uint256):
end

#
# Storage
#

@storage_var
func ERC1155_balances(id: Uint256, account: felt) -> (balance: Uint256):
end

@storage_var
func ERC1155_operator_approvals(account: felt, operator: felt) -> (approved: felt):
end

@storage_var
func ERC1155_uri() -> (uri: felt):
end

namespace ERC1155:

    #
    # Constructor
    #

    func initializer{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            uri_: felt
        ):
        _set_uri(uri_)
        ERC165.register_interface(IERC1155_ID)
        ERC165.register_interface(IERC1155_METADATA_ID)
        return ()
    end

    #
    # Getters
    #

    func uri{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }() -> (uri: felt):
        let (uri) = ERC1155_uri.read()
        return (uri)
    end

    func balance_of{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(account: felt, id: Uint256) -> (balance: Uint256):
        with_attr error_message("ERC1155: balance query for the zero address"):
            assert_not_zero(account)
        end
        let (balance) = ERC1155_balances.read(id, account)
        return (balance)
    end

    func balance_of_batch{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            accounts_len: felt,
            accounts: felt*,
            ids_len: felt,
            ids: Uint256*
        ) -> (
            batch_balances_len: felt,
            batch_balances: Uint256*
        ):
        alloc_locals
        # Check args are equal length arrays
        with_attr error_message("ERC1155: accounts and ids length mismatch"):
            assert ids_len = accounts_len
        end
        # Allocate memory
        let (local batch_balances: Uint256*) = alloc()
        let len = accounts_len
        # Call iterator
        balance_of_batch_iter(len, accounts, ids, batch_balances)
        let batch_balances_len = len
        return (batch_balances_len, batch_balances)
    end

    func is_approved_for_all{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(account: felt, operator: felt) -> (approved: felt):
        let (approved) = ERC1155_operator_approvals.read(account, operator)
        return (approved)
    end

    #
    # Externals
    #

    func set_approval_for_all{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(operator: felt, approved: felt):
        let (caller) = get_caller_address()
        with_attr error_message("ERC1155: cannot approve from the zero address"):
            assert_not_zero(caller)
        end
        _set_approval_for_all(caller, operator, approved)
        return ()
    end

    func safe_transfer_from{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            from_: felt,
            to: felt,
            id: Uint256,
            amount: Uint256,
            data_len: felt,
            data: felt*
        ):
        let (caller) = get_caller_address()
        with_attr error_message("ERC1155: cannot call transfer from the zero address"):
            assert_not_zero(caller)
        end
        with_attr error_message("ERC1155: caller is not owner nor approved"):
            assert_owner_or_approved(from_)
        end
        _safe_transfer_from(from_, to, id, amount, data_len, data)
        return ()
    end

    func safe_batch_transfer_from{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            from_: felt,
            to: felt,
            ids_len: felt,
            ids: Uint256*,
            amounts_len: felt,
            amounts: Uint256*,
            data_len: felt,
            data: felt*
        ):
        let (caller) = get_caller_address()
        with_attr error_message("ERC1155: cannot call transfer from the zero address"):
            assert_not_zero(caller)
        end
        with_attr error_message("ERC1155: transfer caller is not owner nor approved"):
            assert_owner_or_approved(from_)
        end
        _safe_batch_transfer_from(from_, to, ids_len, ids, amounts_len, amounts, data_len, data)
        return ()
    end

    #
    # Internals
    #

    func _safe_transfer_from{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            from_: felt,
            to: felt,
            id: Uint256,
            amount: Uint256,
            data_len: felt,
            data: felt*
        ):
        alloc_locals
        # Check args
        with_attr error_message("ERC1155: transfer to the zero address"):
            assert_not_zero(to)
        end
        with_attr error_message("ERC1155: id is not a valid Uint256"):
            uint256_check(id)
        end
        with_attr error_message("ERC1155: amount is not a valid Uint256"):
            uint256_check(amount)
        end

        # Deduct from sender
        let (from_balance: Uint256) = ERC1155_balances.read(id, from_)
        with_attr error_message("ERC1155: insufficient balance for transfer"):
            let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, amount)
        end
        ERC1155_balances.write(id, from_, new_balance)

        # Add to receiver
        let (to_balance: Uint256) = ERC1155_balances.read(id, to)
        with_attr error_message("ERC1155: balance overflow"):
            let (new_balance: Uint256) = SafeUint256.add(to_balance, amount)
        end
        ERC1155_balances.write(id, to, new_balance)

        # Emit events and check
        let (operator) = get_caller_address()
        TransferSingle.emit(
            operator,
            from_,
            to,
            id,
            amount
        )
        _do_safe_transfer_acceptance_check(
            operator,
            from_,
            to,
            id,
            amount,
            data_len,
            data
        )
        return ()
    end

    func _safe_batch_transfer_from{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            from_: felt,
            to: felt,
            ids_len: felt,
            ids: Uint256*,
            amounts_len: felt,
            amounts: Uint256*,
            data_len: felt,
            data: felt*
        ):
        alloc_locals
        # Check args
        with_attr error_message("ERC1155: transfer to the zero address"):
            assert_not_zero(to)
        end
        with_attr error_message("ERC1155: ids and amounts length mismatch"):
            assert ids_len = amounts_len
        end
        # Recursive call
        let len = ids_len
        safe_batch_transfer_from_iter(from_, to, len, ids, amounts)

        # Emit events and check
        let (operator) = get_caller_address()
        TransferBatch.emit(
            operator,
            from_,
            to,
            ids_len,
            ids,
            amounts_len,
            amounts
        )
        _do_safe_batch_transfer_acceptance_check(
            operator,
            from_,
            to,
            ids_len,
            ids,
            amounts_len,
            amounts,
            data_len,
            data
        )
        return ()
    end

    func _mint{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            to: felt,
            id: Uint256,
            amount: Uint256,
            data_len: felt,
            data: felt*
        ):
        # Cannot mint to zero address
        with_attr error_message("ERC1155: mint to the zero address"):
            assert_not_zero(to)
        end
        # Check uints valid
        with_attr error_message("ERC1155: id is not a valid Uint256"):
            uint256_check(id)
        end
        with_attr error_message("ERC1155: amount is not a valid Uint256"):
            uint256_check(amount)
        end

        # add to minter, check for overflow
        let (to_balance: Uint256) = ERC1155_balances.read(id, to)
        with_attr error_message("ERC1155: balance overflow"):
            let (new_balance: Uint256) = SafeUint256.add(to_balance, amount)
        end
        ERC1155_balances.write(id, to, new_balance)

        # Emit events and check
        let (operator) = get_caller_address()
        TransferSingle.emit(
            operator=operator,
            from_=0,
            to=to,
            id=id,
            value=amount
        )
        _do_safe_transfer_acceptance_check(
            operator=operator,
            from_=0,
            to=to,
            id=id,
            amount=amount,
            data_len=data_len,
            data=data
        )
        return ()
    end

    func _mint_batch{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            to: felt,
            ids_len: felt,
            ids: Uint256*,
            amounts_len: felt,
            amounts: Uint256*,
            data_len: felt,
            data: felt*
        ):
        alloc_locals
        # Cannot mint to zero address
        with_attr error_message("ERC1155: mint to the zero address"):
            assert_not_zero(to)
        end
        # Check args are equal length arrays
        with_attr error_message("ERC1155: ids and amounts length mismatch"):
            assert ids_len = amounts_len
        end

        # Recursive call
        let len = ids_len
        mint_batch_iter(to, len, ids, amounts)

        # Emit events and check
        let (operator) = get_caller_address()
        TransferBatch.emit(
            operator=operator,
            from_=0,
            to=to,
            ids_len=ids_len,
            ids=ids,
            values_len=amounts_len,
            values=amounts,
        )
        _do_safe_batch_transfer_acceptance_check(
            operator=operator,
            from_=0,
            to=to,
            ids_len=ids_len,
            ids=ids,
            amounts_len=amounts_len,
            amounts=amounts,
            data_len=data_len,
            data=data
        )
        return ()
    end

    func _burn{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(from_: felt, id: Uint256, amount: Uint256):
        alloc_locals
        with_attr error_message("ERC1155: burn from the zero address"):
            assert_not_zero(from_)
        end

        # Check uints valid
        with_attr error_message("ERC1155: id is not a valid Uint256"):
            uint256_check(id)
        end
        with_attr error_message("ERC1155: amount is not a valid Uint256"):
            uint256_check(amount)
        end

        # Deduct from burner
        let (from_balance: Uint256) = ERC1155_balances.read(id, from_)
        with_attr error_message("ERC1155: burn amount exceeds balance"):
            let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, amount)
        end
        ERC1155_balances.write(id, from_, new_balance)

        let (operator) = get_caller_address()
        TransferSingle.emit(operator=operator, from_=from_, to=0, id=id, value=amount)
        return ()
    end

    func _burn_batch{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            from_: felt,
            ids_len: felt,
            ids: Uint256*,
            amounts_len: felt,
            amounts: Uint256*
        ):
        alloc_locals
        with_attr error_message("ERC1155: burn from the zero address"):
            assert_not_zero(from_)
        end
        with_attr error_message("ERC1155: ids and amounts length mismatch"):
            assert ids_len = amounts_len
        end

        # Recursive call
        let len = ids_len
        burn_batch_iter(from_, len, ids, amounts)
        let (operator) = get_caller_address()
        TransferBatch.emit(
            operator=operator,
            from_=from_,
            to=0,
            ids_len=ids_len,
            ids=ids,
            values_len=amounts_len,
            values=amounts
        )
        return ()
    end

    func _set_approval_for_all{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(owner: felt, operator: felt, approved: felt):
        # check approved is bool
        assert approved * (approved - 1) = 0
        # caller/owner already checked  non-0
        with_attr error_message("ERC1155: setting approval status for zero address"):
            assert_not_zero(operator)
        end
        with_attr error_message("ERC1155: setting approval status for self"):
            assert_not_equal(owner, operator)
        end
        ERC1155_operator_approvals.write(owner, operator, approved)
        ApprovalForAll.emit(owner, operator, approved)
        return ()
    end

    func _set_uri{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(newuri: felt):
        ERC1155_uri.write(newuri)
        return ()
    end

    func assert_owner_or_approved{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(owner):
        let (caller) = get_caller_address()
        if caller == owner:
            return ()
        end
        let (approved) = ERC1155.is_approved_for_all(owner, caller)
        with_attr error_message("ERC1155: caller is not owner nor approved"):
            assert approved = TRUE
        end
        return ()
    end

end

#
# Private
#

func _do_safe_transfer_acceptance_check{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        operator: felt,
        from_: felt,
        to: felt,
        id: Uint256,
        amount: Uint256,
        data_len: felt,
        data: felt*
    ):
    # Confirm supports IERC1155Reciever interface
    let (is_supported) = IERC165.supportsInterface(to, IERC1155_RECEIVER_ID)
    if is_supported == TRUE:
        let (selector) = IERC1155_Receiver.onERC1155Received(
            to, operator, from_, id, amount, data_len, data
        )

        # Confirm onERC1155Recieved selector returned
        with_attr error_message("ERC1155: ERC1155Receiver rejected tokens"):
            assert selector = ON_ERC1155_RECEIVED_SELECTOR
        end
        return ()
    end

    # Alternatively confirm account
    let (is_account) = IERC165.supportsInterface(to, IACCOUNT_ID)
    with_attr error_message("ERC1155: transfer to non ERC1155Receiver implementer"):
        assert_not_zero(is_account)
    end
    return ()
end

func _do_safe_batch_transfer_acceptance_check{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        operator: felt,
        from_: felt,
        to: felt,
        ids_len: felt,
        ids: Uint256*,
        amounts_len: felt,
        amounts: Uint256*,
        data_len: felt,
        data: felt*
    ):
    # Confirm supports IERC1155Reciever interface
    let (is_supported) = IERC165.supportsInterface(to, IERC1155_RECEIVER_ID)
    if is_supported == TRUE:
        let (selector) = IERC1155_Receiver.onERC1155BatchReceived(
            contract_address=to,
            operator=operator,
            from_=from_,
            ids_len=ids_len,
            ids=ids,
            amounts_len=amounts_len,
            amounts=amounts,
            data_len=data_len,
            data=data
        )
        # Confirm onBatchERC1155Recieved selector returned
        with_attr error_message("ERC1155: ERC1155Receiver rejected tokens"):
            assert selector = ON_ERC1155_BATCH_RECEIVED_SELECTOR
        end
        return ()
    end

    # Alternatively confirm account
    let (is_account) = IERC165.supportsInterface(to, IACCOUNT_ID)
    with_attr error_message("ERC1155: transfer to non ERC1155Receiver implementer"):
        assert is_account = TRUE
    end
    return ()
end

#
# Helpers
#

func balance_of_batch_iter{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        len: felt,
        accounts: felt*,
        ids: Uint256*,
        batch_balances: Uint256*
    ):
    if len == 0:
        return ()
    end
    # Read current entries
    let id: Uint256 = [ids]
    with_attr error_message("ERC1155: id is not a valid Uint256"):
        uint256_check(id)
    end
    let account: felt = [accounts]

    # Get balance
    let (balance: Uint256) = ERC1155.balance_of(account, id)
    assert [batch_balances] = balance
    return balance_of_batch_iter(
        len - 1, accounts + 1, ids + Uint256.SIZE, batch_balances + Uint256.SIZE
    )
end

func safe_batch_transfer_from_iter{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        from_: felt,
        to: felt,
        len: felt,
        ids: Uint256*,
        amounts: Uint256*
    ):
    # Base case
    alloc_locals
    if len == 0:
        return ()
    end

    # Read current entries,  perform Uint256 checks
    let id = [ids]
    with_attr error_message("ERC1155: id is not a valid Uint256"):
        uint256_check(id)
    end
    let amount = [amounts]
    with_attr error_message("ERC1155: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    # deduct from sender
    let (from_balance: Uint256) = ERC1155_balances.read(id, from_)
    with_attr error_message("ERC1155: insufficient balance for transfer"):
        let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, amount)
    end
    ERC1155_balances.write(id, from_, new_balance)

    # add to
    let (to_balance: Uint256) = ERC1155_balances.read(id, to)
    with_attr error_message("ERC1155: balance overflow"):
        let (new_balance: Uint256) = SafeUint256.add(to_balance, amount)
    end
    ERC1155_balances.write(id, to, new_balance)

    # Recursive call
    return safe_batch_transfer_from_iter(
        from_, to, len - 1, ids + Uint256.SIZE, amounts + Uint256.SIZE
    )
end

func mint_batch_iter{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        to: felt,
        len: felt,
        ids: Uint256*,
        amounts: Uint256*
    ):
    # Base case
    alloc_locals
    if len == 0:
        return ()
    end

    # Read current entries
    let id: Uint256 = [ids]
    with_attr error_message("ERC1155: id is not a valid Uint256"):
        uint256_check(id)
    end
    let amount: Uint256 = [amounts]
    with_attr error_message("ERC1155: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    # add to
    let (to_balance: Uint256) = ERC1155_balances.read(id, to)
    with_attr error_message("ERC1155: balance overflow"):
        let (new_balance: Uint256) = SafeUint256.add(to_balance, amount)
    end
    ERC1155_balances.write(id, to, new_balance)

    # Recursive call
    return mint_batch_iter(to, len - 1, ids + Uint256.SIZE, amounts + Uint256.SIZE)
end

func burn_batch_iter{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        from_: felt,
        len: felt,
        ids: Uint256*,
        amounts: Uint256*
    ):
    # Base case
    alloc_locals
    if len == 0:
        return ()
    end

    # Read current entries
    let id: Uint256 = [ids]
    with_attr error_message("ERC1155: id is not a valid Uint256"):
        uint256_check(id)
    end
    let amount: Uint256 = [amounts]
    with_attr error_message("ERC1155: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    # Deduct from burner
    let (from_balance: Uint256) = ERC1155_balances.read(id, from_)
    with_attr error_message("ERC1155: burn amount exceeds balance"):
        let (new_balance: Uint256) = SafeUint256.sub_le(from_balance, amount)
    end
    ERC1155_balances.write(id, from_, new_balance)

    # Recursive call
    return burn_batch_iter(from_, len - 1, ids + Uint256.SIZE, amounts + Uint256.SIZE)
end
