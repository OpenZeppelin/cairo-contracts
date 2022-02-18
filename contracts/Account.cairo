%lang starknet

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_info
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single
)

from contracts.ERC165_base import (
    ERC165_supports_interface, 
    ERC165_register_interface
)

from contracts.utils.constants import PREFIX_TRANSACTION 

#
# Structs
#

struct Message:
    member sender: felt
    member to: felt
    member selector: felt
    member calldata: felt*
    member calldata_size: felt
    member nonce: felt
end

struct MCall:
    member to: felt
    member selector: felt
    member data_offset: felt
    member data_len: felt
end

struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end

#
# Storage
#

@storage_var
func current_nonce() -> (res: felt):
end

@storage_var
func public_key() -> (res: felt):
end

#
# Guards
#

@view
func assert_only_self{syscall_ptr : felt*}():
    let (self) = get_contract_address()
    let (caller) = get_caller_address()
    assert self = caller
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
func get_nonce{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = current_nonce.read()
    return (res=res)
end

@view
func supportsInterface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (interfaceId: felt) -> (success: felt):
    let (success) = ERC165_supports_interface(interfaceId)
    return (success)
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
    # Account magic value derived from ERC165 calculation of IAccount
    ERC165_register_interface(0xbd73c577)
    return()
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
func __execute__{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(
        mcalls_len: felt,
        mcalls: MCall*,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response_len: felt, response: felt*):
    alloc_locals

    let (__fp__, _) = get_fp_and_pc()
    let (tx_info) = get_tx_info()
    let (_current_nonce) = current_nonce.read()

    # validate nonce
    assert _current_nonce = nonce

    # TMP: convert `MCall` to 'Call'
    let (calls : Call*) = alloc()
    from_mcall_to_call(mcalls_len, mcalls, calldata, calls)
    let calls_len = mcalls_len

    # validate transaction
    let (hash) = hash_message(tx_info.account_contract_address, calls_len, calls, nonce, tx_info.max_fee, tx_info.version)
    is_valid_signature(hash, tx_info.signature_len, tx_info.signature)

    # bump nonce
    current_nonce.write(_current_nonce + 1)

    # execute call
    let (response : felt*) = alloc()
    let (response_len) = execute_list(calls_len, calls, response)

    return (response_len=response_len, response=response)
end

func execute_list{syscall_ptr: felt*}(
        calls_len: felt,
        calls: Call*,
        reponse: felt*
    ) -> (response_len: felt):
    alloc_locals

    # if no more calls
    if calls_len == 0:
       return (0)
    end
    
    # do the current call
    let this_call: Call = [calls]
    let res = call_contract(
        contract_address=this_call.to,
        function_selector=this_call.selector,
        calldata_size=this_call.calldata_len,
        calldata=this_call.calldata
    )
    # copy the result in response
    memcpy(reponse, res.retdata, res.retdata_size)
    # do the next calls recursively
    let (response_len) = execute_list(calls_len - 1, calls + Call.SIZE, reponse + res.retdata_size)
    return (response_len + res.retdata_size)
end

func hash_message{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*
    } (
        account: felt,
        calls_len: felt,
        calls: Call*,
        nonce: felt,
        max_fee: felt,
        version: felt
    ) -> (res: felt):
    alloc_locals
    let (calls_hash) = hash_call_array(calls_len, calls)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, PREFIX_TRANSACTION)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, account)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, calls_hash)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, nonce)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, max_fee)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, version)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_call_array{pedersen_ptr: HashBuiltin*}(
        calls_len: felt,
        calls: Call*
    ) -> (res: felt):
    alloc_locals

    # convert [call] to [Hash(call)]
    let (hash_array : felt*) = alloc()
    hash_call_loop(calls_len, calls, hash_array)

    # hash [Hash(call)]
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(hash_state_ptr, hash_array, calls_len)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_call_loop{pedersen_ptr: HashBuiltin*}(
        calls_len: felt,
        calls: Call*,
        hash_array: felt*
    ):
    if calls_len == 0:
        return ()
    end
    let this_call = [calls]
    let (calldata_hash) = hash_calldata(this_call.calldata_len, this_call.calldata)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, this_call.to)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, this_call.selector)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, calldata_hash)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        assert [hash_array] = res
    end
    hash_call_loop(calls_len - 1, calls + Call.SIZE, hash_array + 1)
    return()
end

func hash_calldata{pedersen_ptr: HashBuiltin*}(
        calldata_len: felt,
        calldata: felt*
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

func from_mcall_to_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (
        mcalls_len: felt,
        mcalls: MCall*,
        calldata: felt*,
        calls: Call*
    ):
    alloc_locals

    # if no more mcalls
    if mcalls_len == 0:
       return ()
    end
    
    # parse the first mcall
    assert [calls] = Call(
            to=[mcalls].to,
            selector=[mcalls].selector,
            calldata_len=[mcalls].data_len,
            calldata=calldata + [mcalls].data_offset)
    
    # parse the other mcalls recursively
    from_mcall_to_call(mcalls_len - 1, mcalls + MCall.SIZE, calldata, calls + Call.SIZE)
    return ()
end
