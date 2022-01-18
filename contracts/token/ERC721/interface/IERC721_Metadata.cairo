%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.token.IERC721 import IERC721


@contract_interface
namespace IERC721_Metadata:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func tokenURI(token_id: Uint256) -> (token_uri: felt):
    end
end
