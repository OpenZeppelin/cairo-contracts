%lang starknet

@contract_interface
namespace IERC165:
    func supportsInterface(interfaceId: felt) -> (success: felt):
    end
end
