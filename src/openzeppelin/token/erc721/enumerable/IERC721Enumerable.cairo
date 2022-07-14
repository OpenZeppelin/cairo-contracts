# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (token/erc721/enumerable/IERC721Enumerable.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.IERC721 import IERC721

@contract_interface
namespace IERC721Enumerable:
    func totalSupply() -> (totalSupply: Uint256):
    end

    func tokenByIndex(index: Uint256) -> (tokenId: Uint256):
    end

    func tokenOfOwnerByIndex(owner: felt, index: Uint256) -> (tokenId: Uint256):
    end
end
