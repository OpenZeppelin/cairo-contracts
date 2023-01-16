// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (utils/presets/UniversalDeployer.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, deploy
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import FALSE, TRUE

@event
func ContractDeployed(
    address: felt,
    deployer: felt,
    unique: felt,
    classHash: felt,
    calldata_len: felt,
    calldata: felt*,
    salt: felt
) {
}

@external
func deployContract{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    classHash: felt,
    salt: felt,
    unique: felt,
    calldata_len: felt,
    calldata: felt*
) -> (address: felt) {
    alloc_locals;
    let (deployer) = get_caller_address();

    local _salt;
    local from_zero;
    if (unique == TRUE) {
        let (unique_salt) = hash2{hash_ptr=pedersen_ptr}(deployer, salt);
        _salt = unique_salt;
        from_zero = FALSE;
        tempvar _pedersen = pedersen_ptr;
    } else {
        _salt = salt;
        from_zero = TRUE;
        tempvar _pedersen = pedersen_ptr;
    }

    let pedersen_ptr = _pedersen;

    let (address) = deploy(
        class_hash=classHash,
        contract_address_salt=_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
        deploy_from_zero=from_zero,
    );

    ContractDeployed.emit(
        address=address,
        deployer=deployer,
        unique=unique,
        classHash=classHash,
        calldata_len=calldata_len,
        calldata=calldata,
        salt=salt
    );

    return (address=address);
}
