%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from contracts.Account_base import (
    Account_execute,
    Account_get_nonce,
    Account_initializer,
    Account_get_public_key,
    Account_set_public_key,
    Account_is_valid_signature
)

from contracts.ERC165_base import (
    ERC165_supports_interface, 
    ERC165_register_interface
) 

#
# Getters
#

@view
func get_public_key{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = Account_get_public_key()
    return (res=res)
end

@view
func get_nonce{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = Account_get_nonce()
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
    Account_set_public_key(new_public_key)
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
    }(public_key: felt):
    Account_initializer(public_key)
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
    Account_is_valid_signature(hash, signature_len, signature)
    return ()
end

@external
func execute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr, 
        ecdsa_ptr: SignatureBuiltin*
    }(
        to: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response_len: felt, response: felt*):
    let (response_len, response) = Account_execute(to, selector, calldata_len, calldata, nonce)
    return (response_len=response_len, response=response)
end
