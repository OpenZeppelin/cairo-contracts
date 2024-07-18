use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;

/// Converts panic data into a string (ByteArray).
///
/// panic_data is expected to be a valid serialized byte array with an extra
/// felt252 at the beginning, which is the BYTE_ARRAY_MAGIC.
pub fn panic_data_to_byte_array(panic_data: Array<felt252>) -> ByteArray {
    let mut panic_data = panic_data.span();

    // Remove BYTE_ARRAY_MAGIC from the panic data.
    panic_data.pop_front().unwrap();

    match Serde::<ByteArray>::deserialize(ref panic_data) {
        Option::Some(string) => string,
        Option::None => panic!("Failed to deserialize panic data."),
    }
}

/// Converts a felt252 to a base 16 string padded to 66 characters including the `0x` prefix.
pub fn to_base_16_string(value: felt252) -> ByteArray {
    let mut string = value.format_as_byte_array(16);
    let mut padding = 64 - string.len();

    while padding > 0 {
        string = "0" + string;
        padding -= 1;
    };
    format!("0x{}", string)
}

#[generate_trait]
pub impl IntoBase16String<T, +Into<T, felt252>> of IntoBase16StringTrait<T> {
    fn into_base_16_string(self: T) -> ByteArray {
        to_base_16_string(self.into())
    }
}

/// Asserts that the panic data is an "Entrypoint not found" error, following the starknet foundry
/// emitted error format.
pub fn assert_entrypoint_not_found_error(
    panic_data: Array<felt252>, selector: felt252, contract_address: ContractAddress
) {
    let expected_panic_message = format!(
        "Entry point selector {} not found in contract {}",
        selector.into_base_16_string(),
        contract_address.into_base_16_string()
    );
    assert!(panic_data_to_byte_array(panic_data) == expected_panic_message);
}
