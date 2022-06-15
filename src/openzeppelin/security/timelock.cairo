# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (security/timelock.cairo)

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_in_range
from starkware.starknet.common.syscalls import call_contract, get_block_timestamp
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from starkware.cairo.common.hash_state import (
    HashState,
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from openzeppelin.account.library import Call, AccountCallArray, Account

from openzeppelin.access.accesscontrol import AccessControl

from openzeppelin.introspection.ERC165 import ERC165

from openzeppelin.utils.constants import IERC1155_RECEIVER_ID, IERC721_RECEIVER_ID

#
# Constants
#

# first 250 bits of keccak256 role
const TIMELOCK_ADMIN_ROLE = 0x2fac71d118b1a4c91e71bc07c6ac3ed96b91bc576b354130e48b2a27d342365
const PROPOSER_ROLE = 0x2c26a96bacdc0b3f542dad8af114c98124e3c8492289e875729cd820ada0673
const CANCELLER_ROLE = 0x3f590f1c9c4318f00600966ae9acb4151478d646893962d888e4de0215c9bde
const EXECUTOR_ROLE = 0x362a83cc6525c68a84599e7df08243da4e723538068aa35f90755794d451a79

const DONE_TIMESTAMP = 1

#
# Events
#

@event
func CallScheduled(
    id: felt,
    index: felt,
    target: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
    predecessor: felt,
    delay: felt
):
end

@event
func CallExecuted(
    id: felt,
    index: felt,
    target: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*
):
end

@event
func Cancelled(id: felt):
end

@event
func MinDelayChange(
    oldDuration: felt,
    newDuration: felt
):
end

#
# Storage
#

@storage_var
func Timelock_min_delay() -> (delay: felt):
end

@storage_var
func Timelock_timestamps(id: felt) -> (timestamp: felt):
end

namespace Timelock:
    #
    # Initializer
    #

    func initializer{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(delay: felt, deployer: felt):
        AccessControl._set_role_admin(TIMELOCK_ADMIN_ROLE, TIMELOCK_ADMIN_ROLE)
        AccessControl._set_role_admin(PROPOSER_ROLE, TIMELOCK_ADMIN_ROLE)
        AccessControl._set_role_admin(CANCELLER_ROLE, TIMELOCK_ADMIN_ROLE)
        AccessControl._set_role_admin(EXECUTOR_ROLE, TIMELOCK_ADMIN_ROLE)

        # deployer + self administration
        let (this) = get_contract_address()
        AccessControl._grant_role(TIMELOCK_ADMIN_ROLE, this)
        AccessControl._grant_role(TIMELOCK_ADMIN_ROLE, deployer)

        # register token receiver interfaces
        ERC165.register_interface(IERC721_RECEIVER_ID)
        ERC165.register_interface(IERC1155_RECEIVER_ID)

        _update_delay(delay)
        return ()
    end

    #
    # Guard
    #

    func assert_only_role_or_open_role{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(role: felt):
        let (is_public) = AccessControl.has_role(role, 0)
        if is_public == FALSE:
            AccessControl.assert_only_role(EXECUTOR_ROLE)
            return ()
        end

        return ()
    end

    func is_operation{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (operation: felt):
        let (timestamp: felt) = get_timestamp(id)
        let (operation: felt) = is_not_zero(timestamp)
        return (operation)
    end

    func is_operation_pending{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (pending: felt):
        alloc_locals
        let (timestamp: felt) = get_timestamp(id)
        let (pending: felt) = is_le(DONE_TIMESTAMP + 1, timestamp)
        return (pending)
    end

    func is_operation_ready{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (ready: felt):
        alloc_locals
        let (timestamp) = get_timestamp(id)
        let (current_timestamp) = get_block_timestamp()
        
        let (ready: felt) = is_in_range(timestamp, DONE_TIMESTAMP + 1, current_timestamp)
        return (ready)
    end

    func is_operation_done{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (done: felt):
        let (timestamp: felt) = get_timestamp(id)
        if timestamp == DONE_TIMESTAMP:
            return (TRUE)
        else:
            return (FALSE)
        end
    end

    func get_timestamp{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (timestamp: felt):
        let (timestamp: felt) = Timelock_timestamps.read(id)
        return (timestamp)
    end

    func get_min_delay{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }() -> (min_delay: felt):
        let (min_delay: felt) = Timelock_min_delay.read()
        return (min_delay)
    end

    func hash_operation{
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
        alloc_locals
        let (calls_hash_array: felt*) = _get_calls_hash_array(call_array_len, call_array, calldata)

        let hash_ptr = pedersen_ptr
        with hash_ptr:
            let (hash_state_ptr) = hash_init()
            let (hash_state_ptr) = hash_update(
                hash_state_ptr,
                calls_hash_array,
                call_array_len
            )
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, calldata_len) 
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, predecessor)
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, salt)
            let (res) = hash_finalize(hash_state_ptr)
            let pedersen_ptr = hash_ptr
            return (res)
        end
    end

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
        alloc_locals
        AccessControl.assert_only_role(PROPOSER_ROLE)

        let (id: felt) = hash_operation(call_array_len, call_array, calldata_len, calldata, predecessor, salt)
        let (calls: Call*) = alloc()
        Account._from_call_array_to_call(call_array_len, call_array, calldata, calls)

        let (operation_exists: felt) = is_operation(id)
        let (min_delay: felt) = get_min_delay()

        with_attr error_message("Timelock: operation already scheduled"):
            assert operation_exists = FALSE
        end

        with_attr error_message("Timelock: insufficient delay"):
            assert_le(min_delay, delay)
        end

        let (block_timestamp: felt) = get_block_timestamp()
        tempvar total_time = block_timestamp + delay

        with_attr error_message("Timelock: timestamp overflow"):
            assert_le(block_timestamp, total_time)
            Timelock_timestamps.write(id, total_time)
        end

        _emit_schedule_events(id, 0, call_array_len, calls, predecessor, delay)
        return ()
    end

    func cancel{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt):
        AccessControl.assert_only_role(CANCELLER_ROLE)

        let (pending: felt) = is_operation_pending(id)
        with_attr error_message("Timelock: operation cannot be cancelled"):
            assert pending = TRUE
        end

        Timelock_timestamps.write(id, 0)
        Cancelled.emit(id)
        return ()
    end
      
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
        alloc_locals
        # check if role is public or for only executor
        assert_only_role_or_open_role(EXECUTOR_ROLE)

        let (id: felt) = hash_operation(call_array_len, call_array, calldata_len, calldata, predecessor, salt)
        let (ready: felt) = is_operation_ready(id)

        with_attr error_message("Timelock: operation is not ready"):
            assert ready = TRUE
        end

        if predecessor != FALSE:
            let (predecessor_done: felt) = is_operation_done(predecessor)

            with_attr error_message("Timelock: missing dependency"):
                assert predecessor_done = TRUE
            end
        end

        # reference rebinding
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr: HashBuiltin* = pedersen_ptr

        let (calls: Call*) = alloc()
        Account._from_call_array_to_call(call_array_len, call_array, calldata, calls)
        _execute_calls(id, 0, call_array_len, calls)

        Timelock_timestamps.write(id, DONE_TIMESTAMP)
        return ()
    end

    func update_delay{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(min_delay: felt):
        # checks that the caller is the timelock itself
        let (self) = get_caller_address()
        let (this) = get_contract_address()
        with_attr error_message("Timelock: caller must be timelock"):
            assert self = this
        end

        _update_delay(min_delay)
        return ()
    end

end

#
# Internals
#

func _iter_roles{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(addresses_len: felt, addresses: felt*, role):
    if addresses_len == 0:
        return ()
    end

    # grant role to address
    let address = [addresses]
    AccessControl._grant_role(role, address)

    # recursive call
    _iter_roles(addresses_len - 1, addresses + 1, role)
    return ()
end

func _get_calls_hash_array{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata: felt*
    ) -> (calls_hash_array: felt*):
    alloc_locals

    # TMP: Convert `AccountCallArray` to 'Call'.
    let (calls: Call*) = alloc()
    Account._from_call_array_to_call(call_array_len, call_array, calldata, calls)
    let calls_len = call_array_len

    let (calls_hash_array: felt*) = alloc()
    _hash_calls(calls_len, calls, calls_hash_array)
    return (calls_hash_array)
end

func _hash_calls{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: Call*,
        hash_array: felt*
    ):
    alloc_locals
    if call_array_len == 0:
        return ()
    end

    # hash calldata
    let this_call: Call = [call_array]
    let (local res_calldata) = _hash_calldata(this_call.calldata_len, this_call.calldata)

    # hash chain
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, this_call.to)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, this_call.selector)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, res_calldata)
        let (hash) = hash_finalize(hash_state_ptr)
    end
    let pedersen_ptr = hash_ptr

    # recursive call
    assert [hash_array] = hash
    _hash_calls(call_array_len - 1, call_array + Call.SIZE, hash_array + 1)
    return ()
end

func _hash_calldata{pedersen_ptr: HashBuiltin*}(
        calldata_len: felt,
        calldata: felt*,
    ) -> (res: felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            calldata,
            calldata_len
        )
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func _emit_schedule_events{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        id: felt,
        index: felt,
        calls_len: felt,
        calls: Call*,
        predecessor: felt,
        delay: felt
    ):
    alloc_locals
    if calls_len == 0:
        return ()
    end

    let this_call: Call = [calls]
    CallScheduled.emit(
        id,
        index,
        this_call.to,
        this_call.selector,
        this_call.calldata_len,
        this_call.calldata,
        predecessor,
        delay
    )
    _emit_schedule_events(id, index + 1, calls_len - 1, calls + Call.SIZE, predecessor, delay)
    return ()
end

func _execute_calls{
        syscall_ptr: felt*,
        range_check_ptr
    }(
        id: felt,
        index: felt,
        calls_len: felt,
        calls: Call*
    ):
    alloc_locals
    if calls_len == 0:
        return ()
    end

    let this_call: Call = [calls]
    with_attr error_message("Timelock: underlying transaction reverted"):
        call_contract(
            contract_address=this_call.to,
            function_selector=this_call.selector,
            calldata_size=this_call.calldata_len,
            calldata=this_call.calldata,
        )
    end

    CallExecuted.emit(id, index, this_call.to, this_call.selector, this_call.calldata_len, this_call.calldata)
    _execute_calls(id, index + 1, calls_len - 1, calls + Call.SIZE)
    return ()
end

func _update_delay{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_duration: felt):
    let (old_duration) = Timelock_min_delay.read()
    Timelock_min_delay.write(new_duration)
    MinDelayChange.emit(old_duration, new_duration)
    return ()
end
