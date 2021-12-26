%lang starknet

@contract_interface
namespace IERC1155:
    func balanceOf(owner : felt, token_id : felt) -> (balance : felt):
    end

    func balanceOfBatch(
            owners_len : felt, owners : felt*, tokens_id_len : felt, tokens_id : felt*) -> (
            balance_len : felt, balance : felt*):
    end
    
    func isApprovedForAll(account : felt, operator : felt) -> (res : felt):
    end

    func setApprovalForAll(operator : felt, approved : felt):
    end

    func safeTransferFrom(sender : felt, recipient : felt, token_id : felt, amount : felt):
    end

    func safeBatchTransferFrom(
            sender : felt, recipient : felt, tokens_id_len : felt, tokens_id : felt*,
            amounts_len : felt, amounts : felt*):
    end

    func mint(recipient : felt, token_id : felt, amount : felt) -> ():
    end

    func mint_batch(
            recipient : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
            amounts : felt*) -> ():
    end

    func burn(account : felt, token_id : felt, amount : felt):
    end

    func burn_batch(
            account : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
            amounts : felt*):
    end
end
