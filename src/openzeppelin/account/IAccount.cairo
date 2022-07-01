# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (account/IAccount.cairo)

%lang starknet

from openzeppelin.account.library import AccountCallArray

@contract_interface
namespace IAccount:

    #
    # Getters
    #

    func get_nonce() -> (res : felt):
    end

    #
    # Business logic
    #

    func is_valid_signature(
            hash: felt,
            signature_len: felt,
            signature: felt*
        ) -> (is_valid: felt):
    end

    func __execute__(
            call_array_len: felt,
            call_array: AccountCallArray*,
            calldata_len: felt,
            calldata: felt*,
            nonce: felt
        ) -> (response_len: felt, response: felt*):
    end
end
