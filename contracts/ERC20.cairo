%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage

@storage_var
func balances(user: felt) -> (res: felt):
end

@storage_var
func totalSupply() -> (res: felt):
end

@view
func decimals() -> (res: felt):
    return (18)
end

@view
func balanceOf{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }
    (user: felt) -> (res: felt):
    let (res) = balance.read(user=user)
    return (res)
end

@external
func transfer{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*. range_check_ptr }
    (from: felt, to: felt, amount: felt, sig_r: felt, sig_s: felt) -> (res: felt):
    verify_ecdsa_signature(
        message=amount,
        public_key=from,
        signature_r=sig_r,
        signature_s=sig_s)

    # substract from sender
    let (res) = balances.read(user=to)
    balances.write(to, res - amount)

    # add to recipient
    let (res) = balances.read(user=to)
    balances.write(to, res + amount)
    
    # does it make sense?
    return (1)
end
