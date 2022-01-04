%lang starknet

@contract_interface
namespace IERC165:
    func supportsInterface(interface_id: felt) -> (success: felt):
    end
end
