@contract_interface
namespace IERC20:
    func get_total_supply() -> (res : felt):
    end

    func get_decimals() -> (res : felt):
    end

    func balance_of(user: felt) -> (res : felt):
    end

    func allowance(owner: felt, spender: felt) -> (res : felt):
    end

    func transfer(recipient: felt, amount: felt):
    end

    func transfer_from(sender: felt, recipient: felt, amount: felt):
    end

    func approve(spender: felt, amount: felt):
    end
end
