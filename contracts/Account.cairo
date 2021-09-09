%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_lt

struct Message:
    to: felt
    calldata: felt
    new_nonce: felt
end

struct SignedMessage:
    message: Message
    sig_r: felt
    sig_s: felt
end

@storage_var
func balance() -> (res: felt):
end

@storage_var
func nonce() -> (res: felt):
end

@storage_var
func address() -> (res: felt):
end

@external
func execute{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }
    (signed_message: SignedMessage):

    let (message) = signed_message.message
    let (address) = address.read()

    # verify signature
    verify_ecdsa_signature(
        message=message,
        public_key=address,
        signature_r=signed_message.sig_r,
        signature_s=signed_message.sig_s)

    # validate nonce
    let (current_nonce) = nonce.read()
    assert_lt(current_nonce, message.new_nonce)

    # update nonce
    nonce.write(message.new_nonce)

    # execute call
    # message.to.call(message.calldata)

    return ()
end
