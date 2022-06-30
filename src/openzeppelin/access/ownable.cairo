# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (access/ownable.cairo)

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
func Ownable_owner() -> (owner: felt):
end

namespace Ownable:
    #
    # Constructor
    #

    func initializer{
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

    func assert_only_owner{
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
        let (owner) = Ownable_owner.read()
        return (owner=owner)
    end

    func transfer_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(new_owner: felt):
        with_attr error_message("Ownable: new owner is the zero address"):
            assert_not_zero(new_owner)
        end
        assert_only_owner()
        _transfer_ownership(new_owner)
        return ()
    end

    func renounce_ownership{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        assert_only_owner()
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
        }(new_owner: felt):
        let (previous_owner: felt) = Ownable.owner()
        Ownable_owner.write(new_owner)
        OwnershipTransferred.emit(previous_owner, new_owner)
        return ()
    end

end
