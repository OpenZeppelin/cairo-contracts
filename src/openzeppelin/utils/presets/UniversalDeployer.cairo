%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, deploy
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import FALSE, TRUE

@event
func ContractDeployed(
    address: felt,
    deployer: felt,
    classHash: felt,
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
    let (deployer) = get_caller_address();

    tempvar prefix;
    if (unique == TRUE) {
        prefix = deployer;
    } else {
        prefix = 'UniversalDeployerContract';
    }

    let (_salt) = hash2{hash_ptr=pedersen_ptr}(prefix, salt);

    let (address) = deploy(
        class_hash=classHash,
        contract_address_salt=_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
        deploy_from_zero=FALSE,
    );

    ContractDeployed.emit(
        atddress=address,
        deployer=deployer,
        classHash=classHash,
        salt=salt
    );

    return (address=address);
}
