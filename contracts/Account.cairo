%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_signature
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single
)

#
# Structs
#

struct Message:
    member to: felt
    member selector: felt
    member calldata: felt*
    member calldata_size: felt
    member nonce: felt
end

const MESSAGE_SIZE = 5

#
# Storage
#

@storage_var
func current_nonce() -> (res: felt):
end

@storage_var
func public_key() -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

@storage_var
func address() -> (res: felt):
end

#
# Guards
#

@view
func assert_only_self{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (self) = address.read()
    let (caller) = get_caller_address()
    assert self = caller
    return ()
end

@view
func assert_initialized{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (_initialized) = initialized.read()
    assert _initialized = 1
    return ()
end

#
# Getters
#

@view
func get_public_key{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = public_key.read()
    return (res=res)
end

@view
func get_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = address.read()
    return (res=res)
end

@view
func get_nonce{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = current_nonce.read()
    return (res=res)
end

#
# Setters
#

@external
func set_public_key{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_public_key: felt):
    assert_only_self()
    public_key.write(new_public_key)
    return ()
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_public_key: felt):
    public_key.write(_public_key)
    return()
end

#
# Initializer (will remove once this.address is available for the constructor)
#             

@external
func initialize{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_address: felt):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)
    address.write(_address)
    return ()
end

#
# Business logic
#

@view
func is_valid_signature{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(
        hash: felt,
        signature_len: felt,
        signature: felt*
    ) -> ():
    assert_initialized()
    let (_public_key) = public_key.read()

    # This interface expects a signature pointer and length to make
    # no assumption about signature validation schemes.
    # But this implementation does, and it expects a (sig_r, sig_s) pair.
    let sig_r = signature[0]
    let sig_s = signature[1]

    verify_ecdsa_signature(
        message=hash,
        public_key=_public_key,
        signature_r=sig_r,
        signature_s=sig_s)

    return ()
end

@external
func execute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(
        messages_len: felt,
        messages: felt*
    ) -> (
        responses_len: felt,
        responses: felt*
    ):
    alloc_locals
    assert_initialized()
    assert_not_zero(messages_len)

    # validate transaction
    let (hash) = hash_message_array(messages_len, messages)
    assert hash = 3
    # let (signature_len, signature) = get_tx_signature()
    # is_valid_signature(hash, signature_len, signature)

    # execute transaction
    let (res_len, res) = execute_list(messages_len, messages)
    return (res_len, res)
end

func execute_list{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(
        messages_len: felt,
        messages: felt*
    ) -> (
        responses_len: felt,
        responses: felt*
    ):
    alloc_locals
    let (__fp__, _) = get_fp_and_pc()

    if messages_len == 1:
        let (res_ptr : felt*) = alloc()
        let (res) = _call(&messages[0])
        assert [res_ptr] = res
        return (1, res_ptr)
    end

    let (res) = _call(&messages[0])
    let (res_len, res_ptr) = execute_list(messages_len - 1, messages + MESSAGE_SIZE)
    assert [res_ptr + 1] = res
    return (res_len + 1, &res + 1)
end

func _call{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(message: felt*) -> (response : felt):
    alloc_locals
    let (__fp__, _) = get_fp_and_pc()
    let (_address) = address.read()

    local _message: Message = Message(
        [message],      # to
        [message + 1],  # selector
        &[message + 2], # calldata
        [message + 3],  # calldata_size
        [message + 4]   # nonce
    )

    # check nonce
    let (_current_nonce) = current_nonce.read()
    assert _current_nonce = _message.nonce

    # bump nonce
    current_nonce.write(_current_nonce + 1)

    # execute call
    let response = call_contract(
        contract_address=_message.to,
        function_selector=_message.selector,
        calldata_size=_message.calldata_size,
        calldata=_message.calldata
    )

    return (response=response.retdata_size)
end

func hash_message_array{pedersen_ptr : HashBuiltin*}(
        messages_len: felt,
        messages: felt*
    ) -> (res: felt):
    # to do
    return (3)
end

func hash_message{pedersen_ptr : HashBuiltin*}(message: Message*) -> (res: felt):
    alloc_locals
    # we need to make `res_calldata` local
    # to prevent the reference from being revoked
    let (local res_calldata) = hash_calldata(message.calldata, message.calldata_size)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        # first two iterations are 'to', and 'selector'
        let (hash_state_ptr) = hash_update(
            hash_state_ptr, 
            message, 
            2
        )
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, res_calldata)
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, message.nonce)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
    return (res=res)
    end
end

func hash_calldata{pedersen_ptr: HashBuiltin*}(
        calldata: felt*,
        calldata_size: felt
    ) -> (res: felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            calldata,
            calldata_size
        )
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end
