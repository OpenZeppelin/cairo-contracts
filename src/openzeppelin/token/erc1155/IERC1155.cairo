# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.1 (token/erc1155/IERC1155.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155:

    func balanceOf(account: felt, id: Uint256) -> (balance: Uint256):
    end

    func balanceOfBatch(
            accounts_len: felt,
            accounts: felt*,
            ids_len: felt,
            ids: Uint256*
        ) -> (balances_len: felt, balances: Uint256*):
    end


    func isApprovedForAll(account: felt, operator: felt) -> (isApproved: felt):
    end

    func setApprovalForAll(operator: felt, approved: felt):
    end

    func safeTransferFrom(
            from_: felt,
            to: felt,
            id: Uint256,
            amount: Uint256,
            data_len: felt,
            data: felt*
        ):
    end

    func safeBatchTransferFrom(
            from_: felt,
            to: felt,
            ids_len: felt,
            ids: Uint256*,
            amounts_len: felt,
            amounts: Uint256*,
            data_len: felt,
            data: felt*
        ):
    end

end
