%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.token.ERC20 import erc20_initializer
from contracts.Ownable import get_owner, ownable_initializer
from contracts.Pausable import _pause

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        owner: felt,
        name: felt,
        symbol: felt,
        recipient: felt
    ):
    ownable_initializer(owner)
    erc20_initializer(name, symbol, recipient)
    return ()
end

@external
func pause{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    _pause()
    return ()
end
