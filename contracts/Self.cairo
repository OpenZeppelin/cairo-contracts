%lang starknet

from starkware.starknet.common.syscalls import get_caller_address

@view
func get_self{ syscall_ptr: felt*}() -> (address: felt):
    let (caller) = get_caller_address()
    return (address=caller)
end