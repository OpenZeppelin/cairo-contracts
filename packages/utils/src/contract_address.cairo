use starknet::ContractAddress;

/// Converts a felt252 to a ContractAddress as a constant function.
///
/// Requirements:
///
/// - `value` must be a valid contract address.
pub const fn as_address(value: felt252) -> ContractAddress {
    value.try_into().expect('Invalid contract address')
}

#[generate_trait]
pub impl AsAddressImpl of AsAddressTrait {
    /// Converts a felt252 to a ContractAddress as a constant function.
    ///
    /// Requirements:
    ///
    /// - `value` must be a valid contract address.
    const fn as_address(self: felt252) -> ContractAddress {
        as_address(self)
    }
}
