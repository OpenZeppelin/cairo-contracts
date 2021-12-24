%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC721_Receiver:
    func onERC721Received(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data: felt
    ) -> (ret_val : felt): 
    end
end