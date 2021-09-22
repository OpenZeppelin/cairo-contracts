%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import call_contract
from starkware.starknet.common.storage import Storage

struct Message:
    member to: felt
    member selector: felt
    member calldata: felt*
    member calldata_size: felt
    member nonce: felt
end

struct SignedMessage:
    member message: Message*
    member sig_r: felt
    member sig_s: felt
end

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
func L1_address() -> (res: felt):
end

@external
func initialize{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (_public_key: felt, _L1_address: felt):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    public_key.write(_public_key)
    L1_address.write(_L1_address)
    return ()
end

func hash_message{pedersen_ptr : HashBuiltin*}(message: Message*) -> (res: felt):
    let (res) = hash2{hash_ptr=pedersen_ptr}(message.to, message.selector)
    let (res) = hash_calldata(message.calldata, message.calldata_size)
    let (res) = hash2{hash_ptr=pedersen_ptr}(res, message.nonce)
    return (res=res)
end

func hash_calldata{pedersen_ptr: HashBuiltin*}(
        calldata: felt*,
        calldata_size: felt
    ) -> (res: felt):
    if calldata_size == 0:
        return (res=0)
    end

    if calldata_size == 1:
        return (res=[calldata])
    end

    let _calldata = [calldata]
    let (res) = hash_calldata(calldata, calldata_size - 1)
    let (res) = hash2{hash_ptr=pedersen_ptr}(res, _calldata)
    return (res=res)
end

func validate{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
        range_check_ptr
    } (signed_message: SignedMessage*):
    alloc_locals

    # validate nonce
    let (_current_nonce) = current_nonce.read()
    assert _current_nonce = signed_message.message.nonce

    # reference implicit arguments to prevent them from being revoked by `hash_message`
    local storage_ptr : Storage* = storage_ptr
    local range_check_ptr = range_check_ptr

    # verify signature
    let (message) = hash_message(signed_message.message)
    let (_public_key) = public_key.read()

    verify_ecdsa_signature(
        message=message,
        public_key=_public_key,
        signature_r=signed_message.sig_r,
        signature_s=signed_message.sig_s)

    return ()
end

@external
func execute{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (
        to: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt,
        sig_r: felt,
        sig_s: felt
    ) -> (response : felt):
    alloc_locals

    let (__fp__, _) = get_fp_and_pc()
    local message: Message = Message(to, selector, calldata, calldata_size=calldata_len, nonce)
    local signed_message: SignedMessage = SignedMessage(&message, sig_r, sig_s)

    # validate transaction
    validate(&signed_message)

    # bump nonce
    let (_current_nonce) = current_nonce.read()
    current_nonce.write(_current_nonce + 1)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response=response.retdata_size)
end

#####
# Getters
###

@external
func get_public_key{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }() -> (res: felt):
    let (res) = public_key.read()
    return (res=res)
end

@external
func get_L1_address{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }() -> (res: felt):
    let (res) = L1_address.read()
    return (res=res)
end
