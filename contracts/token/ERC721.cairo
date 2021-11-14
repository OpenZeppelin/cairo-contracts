%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_equal, assert_not_zero

# Missing:
# symbol
# name
# tokenURI
# _baseURI

@storage_var
func owners(token_id : felt) -> (res : felt):
end

@storage_var
func balances(owner : felt) -> (res : felt):
end

@storage_var
func token_approvals(token_id : felt) -> (res : felt):
end

@storage_var
func operator_approvals(owner : felt, operator : felt) -> (res : felt):
end

@storage_var
func initialized() -> (res : felt):
end

@storage_var
func name_() -> (res : felt):
end

@storage_var
func symbol_() -> (res : felt):
end

struct BlockchainNamespace:
    member a : felt
end

# aka ChainID. Chain Agnostic specifies that the length can go up to 32 nines (i.e. 9999999....) but we will only support 31 nines.
struct BlockchainReference:
    member a : felt
end

struct AssetNamespace:
    member a : felt
end

# aka contract Address on L1. An address is represented using 20 bytes. Those bytes are written in the `felt`.
struct AssetReference:
    member a : felt
end

# A tokenId is a u256. u256::MAX() is ~1e77 meaning we need 78 characters to store it. Given a felt can represent
# 31 characters, we need 3 felts to store it.
struct TokenId:
    member a : felt
    member b : felt
    member c : felt
end

# As defined by Chain Agnostics (CAIP-22 and CAIP-29):
# {blockchain_namespace}:{blockchain_reference}/{asset_namespace}:{asset_reference}/{token_id}
struct TokenUri:
    member blockchain_namespace : BlockchainNamespace
    member blockchain_reference : BlockchainReference
    member asset_namespace : AssetNamespace
    member asset_reference : AssetReference
    member token_id : TokenId
end

@storage_var
func token_uri_() -> (res : TokenUri):
end

@external
func initialize{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        name : felt, symbol : felt, tokenURI : TokenUri):
    let (_initialized) = initialized.read()
    assert _initialized = 0

    name_.write(name)
    symbol_.write(name)
    token_uri_.write(tokenURI)

    initialized.write(1)

    return ()
end

@view
func balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt) -> (res : felt):
    assert_not_zero(owner)

    let (res) = balances.read(owner=owner)
    return (res)
end

@view
func owner_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (res) = owners.read(token_id=token_id)
    assert_not_zero(res)

    return (res)
end

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = name_.read()
    return (res)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = symbol_.read()

    return (res)
end

@view
func token_uri{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : TokenUri):
    let (res) = token_uri_.read()

    return (res)
end

func _approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, token_id : felt):
    token_approvals.write(token_id=token_id, value=to)
    return ()
end

@external
func approve{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : felt):
    let (owner) = owners.read(token_id)

    assert_not_equal(owner, to)

    let (is_operator_or_owner) = _is_operator_or_owner(owner)
    assert_not_zero(is_operator_or_owner)

    _approve(to, token_id)
    return ()
end

func _is_operator_or_owner{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        address : felt) -> (res : felt):
    let (caller) = get_caller_address()

    if caller == address:
        return (1)
    end

    let (is_approved_for_all) = operator_approvals.read(owner=caller, operator=address)
    return (is_approved_for_all)
end

func _is_approved_or_owner{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        spender : felt, token_id : felt) -> (res : felt):
    alloc_locals

    let (exists) = _exists(token_id)
    assert exists = 1

    let (owner) = owner_of(token_id)
    if owner == spender:
        return (1)
    end

    let (approved_addr) = get_approved(token_id)
    if approved_addr == spender:
        return (1)
    end

    let (is_operator) = is_approved_for_all(owner, spender)
    if is_operator == 1:
        return (1)
    end

    return (0)
end

func _exists{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (res) = owners.read(token_id)

    if res == 0:
        return (0)
    else:
        return (1)
    end
end

@view
func get_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    let (res) = token_approvals.read(token_id=token_id)
    return (res)
end

@view
func is_approved_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt) -> (res : felt):
    let (res) = operator_approvals.read(owner=owner, operator=operator)
    return (res)
end

func _mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : felt):
    assert_not_zero(to)

    let (exists) = _exists(token_id)
    assert exists = 0

    let (balance) = balances.read(to)
    balances.write(to, balance + 1)

    owners.write(token_id, to)

    return ()
end

func _burn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(token_id : felt):
    alloc_locals

    let (local owner) = owner_of(token_id)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (balance) = balances.read(owner)
    balances.write(owner, balance - 1)

    # Delete owner
    owners.write(token_id, 0)

    return ()
end

func _transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, token_id : felt):
    let (_owner_of) = owner_of(token_id)
    assert _owner_of = _from

    assert_not_zero(to)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (owner_bal) = balances.read(_from)
    balances.write(owner=_from, value=(owner_bal - 1))

    # Increase receiver balance
    let (receiver_bal) = balances.read(to)
    balances.write(owner=to, value=(receiver_bal + 1))

    # Update token_id owner
    owners.write(token_id=token_id, value=to)

    return ()
end

func _set_approval_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt, approved : felt):
    assert_not_equal(owner, operator)

    # Make sure `approved` is a boolean (0 or 1)
    assert approved * (1 - approved) = 0

    operator_approvals.write(owner=owner, operator=operator, value=approved)
    return ()
end

@external
func set_approval_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    let (caller) = get_caller_address()

    _set_approval_for_all(caller, operator, approved)
    return ()
end

@external
func transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, token_id : felt):
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id=token_id)

    _transfer(_from, to, token_id)
    return ()
end
