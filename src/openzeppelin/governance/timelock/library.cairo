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
# Structs
#

# tmp structs needed for external methods

struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end

struct TimelockCall:
    member to: felt
    member selector: felt
    member data_offset: felt
    member data_len: felt
end

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
func MinDelayChange(old_duration: felt, new_duration: felt):
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
        call_array: TimelockCall*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
        delay: felt,
    ):
        alloc_locals

        let (id: felt) = hash_operation(call_array_len, call_array, calldata, predecessor, salt)

        let (calls: Call*) = alloc()
        _from_timelock_calls_to_calls(call_array_len, call_array, calldata, calls)
        _schedule(id, delay, call_array_len, calls, predecessor)

        return ()
    end

    func execute{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: TimelockCall*,
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

        _execute(id, call_array_len, call_array, calldata_len, calldata, predecessor)

        Timelock_timestamps.write(id, 1)

        return ()
    end

    func cancel{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(id: felt):
        _cancel(id)

        Cancelled.emit(id)

        return ()
    end

    func _schedule{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        id: felt, 
        delay: felt,
        calls_len: felt, 
        calls: Call*,
        predecessor: felt
    ):
        let (operation_exists: felt) = is_operation(id)
        let (min_delay: felt) = get_min_delay()

        with_attr error_message("Timelock: operation already scheduled"):
            assert operation_exists = FALSE
        end

        with_attr error_message("Timelock: insufficient delay"):
            assert_le(min_delay, delay)
        end

        let (block_timestamp: felt) = get_block_timestamp()

        Timelock_timestamps.write(id, block_timestamp + delay)

        _emit_schedule_events(id, 0, calls_len, calls, predecessor)

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
        predecessor: felt
    ):
        alloc_locals

        if calls_len == 0:
            return ()
        end

        let this_call: Call = [calls]

        CallScheduled.emit(
            id, index, this_call.to, this_call.selector, this_call.calldata_len, this_call.calldata, predecessor
        )

        _emit_schedule_events(id, index + 1, calls_len - 1, calls + Call.SIZE, predecessor)

        return ()
    end

    func _execute{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        id: felt,
        call_array_len: felt,
        call_array: TimelockCall*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
    ):
        alloc_locals

        let (calls: Call*) = alloc()
        _from_timelock_calls_to_calls(call_array_len, call_array, calldata, calls)
        _execute_calls(id, 0, call_array_len, calls)

        return ()
    end

    func _cancel{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(id: felt):
        let (pending: felt) = is_operation_pending(id)

        with_attr error_message("Timelock: operation cannot be cancelled"):
            assert pending = TRUE
        end

        Timelock_timestamps.write(id, 0)

        return ()
    end

    func hash_operation{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        call_array_len: felt,
        call_array: TimelockCall*,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
    ) -> (hash: felt):
        alloc_locals

        let (calls_hash_array: felt*) = _get_calls_hash_array(call_array_len, call_array, calldata)

        let (state: HashState*) = hash_init()

        let (state: HashState*) = hash_update{hash_ptr=pedersen_ptr}(
            state, calls_hash_array, call_array_len
        )

        let (state: HashState*) = hash_update_single{hash_ptr=pedersen_ptr}(state, predecessor)
        let (state: HashState*) = hash_update_single{hash_ptr=pedersen_ptr}(state, salt)

        let (hash: felt) = hash_finalize{hash_ptr=pedersen_ptr}(state)

        return (hash=hash)
    end

    func _get_calls_hash_array{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        call_array_len: felt, 
        call_array: TimelockCall*, 
        calldata: felt*
    ) -> (calls_hash_array: felt*):
        alloc_locals

        let (calls: Call*) = alloc()
        _from_timelock_calls_to_calls(call_array_len, call_array, calldata, calls)
        let calls_len = call_array_len

        let (calls_hash_array: felt*) = alloc()
        _hash_calls(calls_len, calls, calls_hash_array)

        return (calls_hash_array=calls_hash_array)
    end

    func _from_timelock_calls_to_calls{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        call_array_len: felt, 
        call_array: TimelockCall*, 
        calldata: felt*, 
        calls: Call*
    ):
        if call_array_len == 0:
            return ()
        end

        assert [calls] = Call(
            to=[call_array].to,
            selector=[call_array].selector,
            calldata_len=[call_array].data_len,
            calldata=calldata + [call_array].data_offset
            )

        _from_timelock_calls_to_calls(call_array_len - 1, call_array + TimelockCall.SIZE, calldata, calls + Call.SIZE)

        return ()
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

        let (state: HashState*) = hash_init()
        let (state: HashState*) = hash_update_single{hash_ptr=pedersen_ptr}(state, [call_array].to)

        let (state: HashState*) = hash_update_single{hash_ptr=pedersen_ptr}(
            state, [call_array].selector
        )

        let (state: HashState*) = hash_update{hash_ptr=pedersen_ptr}(
            state, [call_array].calldata, [call_array].calldata_len
        )

        let (hash: felt) = hash_finalize{hash_ptr=pedersen_ptr}(state)
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
