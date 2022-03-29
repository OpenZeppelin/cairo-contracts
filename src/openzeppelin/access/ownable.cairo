# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (access/ownable.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero

#
# Events
#

@event
func OwnershipTransferred(previousOwner: felt, newOwner: felt):
end

#
# Storage
#

@storage_var
func _owner() -> (owner: felt):
end

#
# Constructor
#

func Ownable_initializer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    _transferOwnership(owner)
    return ()
end

#
# Protector (Modifier)
#

func Ownable_onlyOwner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = Ownable_owner()
    let (caller) = get_caller_address()
    with_attr error_message("Ownable: caller is not the owner"):
        assert owner = caller
    end
    return ()
end

#
# Getters
#

func Ownable_owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = _owner.read()
    return (owner=owner)
end

func Ownable_transferOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(newOwner: felt):
    with_attr error_message("Ownable: new owner is the zero address"):
        assert_not_zero(newOwner)
    end
    Ownable_onlyOwner()
    _transferOwnership(newOwner)
    return ()
end

func Ownable_renounceOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Ownable_onlyOwner()
    _transferOwnership(0)
    return ()
end

#
# Internal
#

func _transferOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(newOwner: felt):
    let (previousOwner: felt) = Ownable_owner()
    _owner.write(newOwner)
    OwnershipTransferred.emit(previousOwner, newOwner)
    return ()
end
