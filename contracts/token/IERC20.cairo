%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20:
    func get_total_supply() -> (res: Uint256):
    end

    func get_decimals() -> (res: felt):
    end

    func balance_of(account: felt) -> (res: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (res: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256):
    end

    func transfer_from(sender: felt, recipient: felt, amount: Uint256):
    end

    func approve(spender: felt, amount: Uint256):
    end
end
