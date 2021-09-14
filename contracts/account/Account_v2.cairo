%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage
from starkware.starknet.common import syscall_ptr
from starkware.starknet.common import call_contract

struct Message:
    to: felt
    selector: felt
    calldata: felt
    calldata_size: felt
    nonce: felt
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
func public_key() -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

@external
func initialize{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* } (_public_key: felt):
    assert initialized.read() = 0
    initialized.write(1)
    public_key.write(_public_key)
    return ()
end

@view
func validate{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }(signed_message: SignedMessage):
    # validate nonce
    assert nonce.read() = signed_message.message.nonce

    # verify signature
    verify_ecdsa_signature(
        # to do: this should be a felt, not a struct
        message=signed_message.message,
        public_key=public_key.read(),
        signature_r=signed_message.sig_r,
        signature_s=signed_message.sig_s)

    return ()
end

@external
func execute{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr, syscall_ptr }
    (signed_message: SignedMessage) -> (response_size : felt, response : felt*):

    let message = signed_message.message

    # validate transaction
    validate(signed_message)

    # bump nonce
    nonce.write(nonce.read() + 1)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response_size=response.retdata_size, response=response.retdata)
end
