%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_lt

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
func validate_transaction{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*. range_check_ptr }
    (to: felt, _nonce: felt, message: felt, sig_r: felt, sig_s: felt):

    # verify signature
    let (address) = address.read()
    verify_ecdsa_signature(
        message=message,
        public_key=address,
        signature_r=sig_r,
        signature_s=sig_s)

    # validate nonce
    let (current_nonce) = nonce.read()
    assert_lt(current_nonce, _nonce)

    # update nonce
    nonce.write(_nonce)
    return ()
end
