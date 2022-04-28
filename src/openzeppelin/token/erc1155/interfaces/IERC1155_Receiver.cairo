%lang starknet
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155_Receiver:

    func onERC1155Received(
            operator : felt, _from : felt, id : Uint256, value : Uint256,
            data_len : felt, data : felt*) -> (selector : felt):
    end

    func onERC1155BatchReceived(
            operator : felt, _from : felt, ids_len : felt, ids : Uint256*, 
            values_len : felt, values : Uint256*, data_len : felt, data : felt*)
            -> (selector : felt):
    end

    func supportsInterface(interfaceId : felt) -> (success : felt):
    end

end