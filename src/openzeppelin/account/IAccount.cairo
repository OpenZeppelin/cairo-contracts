# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.3.2 (account/IAccount.cairo)

%lang starknet

from openzeppelin.account.library import AccountCallArray

@contract_interface
namespace IAccount:

    #
    # Getters
    #

    func getNonce() -> (nonce : felt):
    end

    #
    # Business logic
    #

    func isValidSignature(
            hash: felt,
            signature_len: felt,
            signature: felt*
        ) -> (isValid: felt):
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
