# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.3.2 (account/presets/Account.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin

from openzeppelin.account.library import Account, AccountCallArray

from openzeppelin.introspection.erc165.library import ERC165

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(publicKey: felt):
    Account.initializer(publicKey)
    return ()
end

#
# Getters
#

@view
func getPublicKey{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (publicKey: felt):
    let (publicKey) = Account.get_public_key()
    return (publicKey=publicKey)
end

@view
func getNonce{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (nonce: felt):
    let (nonce) = Account.get_nonce()
    return (nonce=nonce)
end

@view
func supportsInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (interfaceId: felt) -> (success: felt):
    return ERC165.supports_interface(interfaceId)
end

#
# Setters
#

@external
func setPublicKey{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(newPublicKey: felt):
    Account.set_public_key(newPublicKey)
    return ()
end

#
# Business logic
#

@view
func isValidSignature{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        hash: felt,
        signature_len: felt,
        signature: felt*
    ) -> (isValid: felt):
    let (isValid) = Account.is_valid_signature(hash, signature_len, signature)
    return (isValid=isValid)
end

@external
func __execute__{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*,
        bitwise_ptr: BitwiseBuiltin*
    }(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response_len: felt, response: felt*):
    let (response_len, response) = Account.execute(
        call_array_len,
        call_array,
        calldata_len,
        calldata,
        nonce
    )
    return (response_len=response_len, response=response)
end
