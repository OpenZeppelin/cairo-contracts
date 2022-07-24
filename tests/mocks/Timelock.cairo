# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.utils.constants.library import (
    IERC721_RECEIVER_ID,
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR
)

from openzeppelin.security.timelock.library import (
    Timelock,
    PROPOSER_ROLE,
    CANCELLER_ROLE,
    EXECUTOR_ROLE,
)

from openzeppelin.introspection.erc165.library import ERC165

from openzeppelin.access.accesscontrol.library import AccessControl

from openzeppelin.account.library import AccountCallArray


@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        minDelay: felt,
        deployer: felt,
        proposers_len: felt,
        proposers: felt*,
        executors_len: felt,
        executors: felt*,
        cancellers_len: felt,
        cancellers: felt*
    ):
    alloc_locals
    AccessControl.initializer()
    Timelock.initializer(minDelay, deployer)

    # grant proposer, executor, and canceller roles
    Timelock._iter_roles(proposers_len, proposers, PROPOSER_ROLE)
    Timelock._iter_roles(executors_len, executors, EXECUTOR_ROLE)
    Timelock._iter_roles(cancellers_len, cancellers, CANCELLER_ROLE)
    return ()
end

@view
func supportsInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (interfaceId: felt) -> (success: felt):
    let (success) = ERC165.supports_interface(interfaceId)
    return (success)
end

@view
func isOperation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt) -> (is_operation: felt):
    let (operation) = Timelock.is_operation(id)
    return (operation)
end

@view
func isOperationPending{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt) -> (is_pending: felt):
    let (isPending) = Timelock.is_operation_pending(id)
    return (isPending)
end

@view
func isOperationReady{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt) -> (is_ready: felt):
    let (isReady) = Timelock.is_operation_ready(id)
    return (isReady)
end

@view
func isOperationDone{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt) -> (is_done: felt):
    let (isDone) = Timelock.is_operation_done(id)
    return (isDone)
end

@view
func getTimestamp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt) -> (timestamp: felt):
    let (timestamp) = Timelock.get_timestamp(id)
    return (timestamp)
end

@view
func getMinDelay{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (minDelay: felt):
    let (minDelay) = Timelock.get_min_delay()
    return (minDelay)
end

@view
func hashOperation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
    ) -> (hash: felt):
    let (hash) = Timelock.hash_operation(
        call_array_len, call_array, calldata_len, calldata, predecessor, salt)
    return (hash)
end

@external
func schedule{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
        delay: felt,
    ):
    Timelock.schedule(
        call_array_len,
        call_array,
        calldata_len,
        calldata,
        predecessor,
        salt,
        delay
    )
    return ()
end

@external
func cancel{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(id: felt):
    Timelock.cancel(id)
    return ()
end

@external
func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
    ):
    Timelock.execute(
        call_array_len,
        call_array,
        calldata_len,
        calldata,
        predecessor,
        salt
    )
    return ()
end

@external
func updateDelay{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_delay: felt):
    Timelock.update_delay(new_delay)
    return ()
end

@view
func onERC721Received(
        operator: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt):
    return (IERC721_RECEIVER_ID)
end

@view
func onERC1155Received(
        operator: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt):
    return (ON_ERC1155_RECEIVED_SELECTOR)
end

@view
func onERC1155BatchReceived(
        operator: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt):
    return (ON_ERC1155_BATCH_RECEIVED_SELECTOR)
end

@external
func grantRole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt):
    AccessControl.grant_role(role, user)
    return ()
end

@view
func hasRole{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt) -> (hasRole: felt):
    let (hasRole) = AccessControl.has_role(role, user)
    return (hasRole)
end
