%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC721_Receiver:
    func onERC721Received(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    end
end
