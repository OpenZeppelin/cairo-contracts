%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.token.IERC721 import IERC721

@contract_interface
namespace IERC721_Enumerable:
    func totalSupply() -> (totalSupply: Uint256):
    end

    func tokenByIndex(index: Uint256) -> (tokenId: Uint256):
    end

    func tokenOfOwnerByIndex(owner: felt, index: Uint256) -> (tokenId: Uint256):
    end
end
