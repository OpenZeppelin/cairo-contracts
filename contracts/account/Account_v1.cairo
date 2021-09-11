%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_lt
from starkware.starknet.common import syscall_ptr
from starkware.starknet.common import call_contract

struct Message:
    to: felt
    selector: felt
    calldata: felt
    calldata_size: felt
    new_nonce: felt
end

struct SignedMessage:
    message: Message
    sig_r: felt
    sig_s: felt
end

@storage_var
func nonce() -> (res: felt):
end

@storage_var
func address() -> (res: felt):
end

@view
func validate{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }
    (signed_message: SignedMessage):

    let message = signed_message.message
    let address = address.read()

    # verify signature
    verify_ecdsa_signature(
        message=message,
        public_key=address,
        signature_r=signed_message.sig_r,
        signature_s=signed_message.sig_s)

    # validate nonce
    let current_nonce = nonce.read()
    assert_lt(current_nonce, message.new_nonce)

    return ()
end

@external
func execute{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr, syscall_ptr }
    (signed_message: SignedMessage) -> (response_size : felt, response : felt*):

    let message = signed_message.message

    # validate transaction
    validate(SignedMessage)

    # update nonce
    # todo: decide between any larger nonce or strict +1
    nonce.write(message.new_nonce)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response=response.retdata, response_size=response.retdata_size)
end
