%lang starknet

@contract_interface
namespace IAccount:
    #
    # Getters
    #

    func get_public_key() -> (res : felt):
    end

    func get_address() -> (res : felt):
    end

    func get_L1_address() -> (res : felt):
    end

    func get_nonce() -> (res : felt):
    end

    #
    # Setters
    #
    func set_public_key(new_public_key: felt):
    end

    func set_L1_address(new_L1_address: felt):
    end

    #
    # Business logic
    #

    func is_valid_signature(hash: felt, signature_len: felt, signature: felt*):
    end

    func execute(
            to: felt,
            selector: felt,
            calldata_len: felt,
            calldata: felt*,
            signature_len: felt,
            signature: felt*
        ) -> (response: felt):
    end
end
