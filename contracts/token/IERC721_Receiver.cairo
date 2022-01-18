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


    # ERC721's `safeTransferFrom` requires a means of differentiating between account and
    # non-account contracts. Currently, StarkNet does not support error handling from the
    # contract level; therefore, this ERC721 implementation requires that all contracts that
    # support safe ERC721 transfers (both accounts and non-accounts) include the `is_account` 
    # method. This method should return `0` since it's NOT an account.
    func is_account() -> (res: felt):
    end
end
