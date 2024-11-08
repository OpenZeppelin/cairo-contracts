// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.19.0 (utils/bytearray.cairo)

use core::byte_array::ByteArrayTrait;
use core::poseidon::poseidon_hash_span;
use core::to_byte_array::FormatAsByteArray;

/// Reads n bytes from a byte array starting from a given index.
///
/// Requirements:
///
/// - `start + n` must be less than or equal to the length of the byte array.
pub fn read_n_bytes(data: @ByteArray, start: u32, n: u32) -> ByteArray {
    assert(start + n <= data.len(), 'ByteArray: out of bounds');

    let mut result: ByteArray = Default::default();
    for i in 0..n {
        result.append_byte(data[start + i]);
    };
    result
}

/// Converts a value to a byte array with a given base and padding.
///
/// Requirements:
///
/// - `base` can not be zero.
pub fn to_byte_array<T, +Into<T, felt252>, +Copy<T>>(
    value: @T, base: u8, padding: u16
) -> ByteArray {
    let value: felt252 = (*value).into();
    let base: felt252 = base.into();
    let mut byte_array = value.format_as_byte_array(base.try_into().unwrap());

    if padding.into() > byte_array.len() {
        let mut padding = padding.into() - byte_array.len();
        while padding > 0 {
            byte_array = "0" + byte_array;
            padding -= 1;
        };
    };
    byte_array
}

/// Returns a unique hash given a ByteArray.
///
/// The hash is computed by serializing the data into a span of felts, and
/// then hashing the span using the Poseidon hash algorithm.
pub fn hash_byte_array(data: @ByteArray) -> felt252 {
    let mut serialized = array![];
    data.serialize(ref serialized);

    poseidon_hash_span(serialized.span())
}

/// ByteArray extension trait.
#[generate_trait]
pub impl ByteArrayExtImpl of ByteArrayExtTrait {
    // Reads n bytes from a byte array starting from a given index.
    ///
    /// Requirements:
    ///
    /// - `start + n` must be less than or equal to the length of the byte array.
    fn read_n_bytes(self: @ByteArray, start: u32, n: u32) -> ByteArray {
        read_n_bytes(self, start, n)
    }

    /// Converts a value to a byte array with a given base and padding.
    ///
    /// Requirements:
    ///
    /// - `base` can not be zero.
    fn to_byte_array<T, +Into<T, felt252>, +Copy<T>>(
        self: @T, base: u8, padding: u16
    ) -> ByteArray {
        to_byte_array(self, base, padding)
    }

    /// Hashes a byte array using the Poseidon hash algorithm.
    /// Encodes the byte array as a ´Span<felt252>´ by serializing ´data´.
    fn hash(self: @ByteArray) -> felt252 {
        hash_byte_array(self)
    }
}
