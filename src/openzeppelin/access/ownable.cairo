# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (access/ownable.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
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

namespace Ownable:
    #
    # Constructor
    #

    func constructor{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(owner: felt):
        _transfer_ownership(owner)
        return ()
    end

    #
    # Protector (Modifier)
    #

    func _only_owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        let (owner) = Ownable.owner()
        let (caller) = get_caller_address()
        with_attr error_message("Ownable: caller is not the owner"):
            assert owner = caller
        end
        return ()
    end

    #
    # Public
    #

    func owner{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (owner: felt):
        let (owner) = _owner.read()
        return (owner=owner)
    end

    func transfer_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(newOwner: felt):
        with_attr error_message("Ownable: new owner is the zero address"):
            assert_not_zero(newOwner)
        end
        _only_owner()
        _transfer_ownership(newOwner)
        return ()
    end

    func renounce_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        _only_owner()
        _transfer_ownership(0)
        return ()
    end

    #
    # Internal
    #

    func _transfer_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(newOwner: felt):
        let (previousOwner: felt) = Ownable.owner()
        _owner.write(newOwner)
        OwnershipTransferred.emit(previousOwner, newOwner)
        return ()
    end

end