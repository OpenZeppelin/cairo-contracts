%lang starknet

from starkware.cairo.common.uint256 import Uint256

from contracts.IERC165 import IERC165

@contract_interface
namespace IERC721:
    func balanceOf(owner: felt) -> (balance: Uint256):
    end

    func ownerOf(token_id: Uint256) -> (owner: felt):
    end

    func safeTransferFrom(
            _from: felt, 
            to: felt, 
            token_id: Uint256, 
            data_len: felt,
            data: felt*
        ):
    end

    func transferFrom(_from: felt, to: felt, token_id: Uint256):
    end

    func approve(approved: felt, token_id: Uint256):
    end

    func setApprovalForAll(operator: felt, approved: felt):
    end

    func getApproved(token_id: Uint256) -> (approved: felt):
    end

    func isApprovedForAll(owner: felt, operator: felt) -> (is_approved: felt):
    end
end
