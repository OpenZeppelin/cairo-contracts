# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (security/initializable.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func Initializable_initialized() -> (res: felt):
end

namespace Initializable:

    func initialized{ 
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }() -> (res: felt):
        let (res) = Initializable_initialized.read()
        return (res=res)
    end

    func initialize{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        let (is_initialized) = Initializable_initialized.read()
        with_attr error_message("Initializable: contract already initialized"):
            assert is_initialized = FALSE
        end
        Initializable_initialized.write(TRUE)
        return ()
    end

end
