# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (governance/timelock/library.cairo)

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.starknet.common.syscalls import call_contract, get_block_timestamp

from openzeppelin.account.library import Call, AccountCallArray, Account

from openzeppelin.security.safemath import SafeUint256

from starkware.cairo.common.hash_state import (
    HashState,
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

#
# Constants
#

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
func MinDelayChange(oldDuration: felt, newDuration: felt):
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
    func initializer{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(delay: felt):
        Timelock_min_delay.write(delay)
        MinDelayChange.emit(0, delay)
        return ()
    end

    func get_min_delay{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }() -> (min_delay: felt):
        let (min_delay: felt) = Timelock_min_delay.read()
        return (min_delay)
    end

    func get_timestamp{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (timestamp: felt):
        let (timestamp: felt) = Timelock_timestamps.read(id)
        return (timestamp=timestamp)
    end

    func is_operation{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (operation: felt):
        let (timestamp: felt) = get_timestamp(id)
        let (operation: felt) = is_not_zero(timestamp)
        return (operation=operation)
    end

    func is_operation_pending{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (pending: felt):
        alloc_locals
        let (timestamp: felt) = get_timestamp(id)
        let (pending: felt) = is_le(DONE_TIMESTAMP + 1, timestamp)
        return (pending=pending)
    end

    func is_operation_ready{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt) -> (ready: felt):
        alloc_locals

        let (timestamp: felt) = get_timestamp(id)
        let (block_timestamp: felt) = get_block_timestamp()

        let (pending: felt) = is_operation_pending(id)
        let (ready: felt) = is_le(timestamp, block_timestamp)

        if pending + ready == 2:
            return (TRUE)
        else:
            return (FALSE)
        end
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

    func update_delay{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(min_delay: felt):
        let (old_min_delay: felt) = Timelock_min_delay.read()
        Timelock_min_delay.write(min_delay)
        MinDelayChange.emit(old_min_delay, min_delay)
        return ()
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
        let (id: felt) = hash_operation(call_array_len, call_array, calldata, predecessor, salt)
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

        let (id: felt) = hash_operation(call_array_len, call_array, calldata, predecessor, salt)
        let (ready: felt) = is_operation_ready(id)

        with_attr error_message("Timelock: operation is not ready"):
            assert ready = TRUE
        end

        if predecessor != 0:
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

    func cancel{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(id: felt):
        let (pending: felt) = is_operation_pending(id)
        with_attr error_message("Timelock: operation cannot be cancelled"):
            assert pending = TRUE
        end

        Timelock_timestamps.write(id, 0)
        Cancelled.emit(id)
        return ()
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

    func hash_operation{
            syscall_ptr: felt*,
            pedersen_ptr: HashBuiltin*,
            range_check_ptr
        }(
            call_array_len: felt,
            call_array: AccountCallArray*,
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
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, predecessor)
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, salt)
            let (res) = hash_finalize(hash_state_ptr)
            let pedersen_ptr = hash_ptr
            return (res)
        end
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
        let (calls: Call*) = alloc()
        Account._from_call_array_to_call(call_array_len, call_array, calldata, calls)

        let calls_len = call_array_len
        let (calls_hash_array: felt*) = alloc()
        _hash_calls(calls_len, calls, calls_hash_array)

        return (calls_hash_array=calls_hash_array)
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
        if call_array_len == 0:
            return ()
        end

        # hash chain
        let hash_ptr = pedersen_ptr
        with hash_ptr:
            let (hash_state_ptr) = hash_init()
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, [call_array].to)
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, [call_array].selector)
            let (hash_state_ptr) = hash_update_single(hash_state_ptr, [call_array].calldata_len)
            let (hash) = hash_finalize(hash_state_ptr)
        end
        let pedersen_ptr = hash_ptr

        # recursive call
        assert [hash_array] = hash
        _hash_calls(call_array_len - 1, call_array + Call.SIZE, hash_array + 1)
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
        call_contract(
            contract_address=this_call.to,
            function_selector=this_call.selector,
            calldata_size=this_call.calldata_len,
            calldata=this_call.calldata,
        )

        CallExecuted.emit(id, index, this_call.to, this_call.selector, this_call.calldata_len, this_call.calldata)
        _execute_calls(id, index + 1, calls_len - 1, calls + Call.SIZE)
        return ()
    end
end
