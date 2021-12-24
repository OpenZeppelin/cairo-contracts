%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.IERC165 import IERC165
from contracts.token.IERC721 import IERC721


@contract_interface
namespace IERC721_Metadata:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func tokenURI(token_id: Uint256) -> (uri_len: felt, uri: felt*):
    end
end
