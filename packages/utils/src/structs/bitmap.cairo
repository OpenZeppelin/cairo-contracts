// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0 (utils/src/structs/bitmap.cairo)

use core::num::traits::{Bounded, Pow, Zero};
use starknet::storage::{Map, Mutable, StorageMapReadAccess, StorageMapWriteAccess, StoragePath};

/// Compact bitset for sequential u256 indices.
///
/// Packs 256 booleans per storage slot, reducing storage reads/writes for adjacent indices.
#[starknet::storage_node]
pub struct BitMap {
    pub data: Map<u256, u256>,
}

#[generate_trait]
pub impl BitMapImpl of BitMapTrait {
    /// Returns whether the bit at `index` is set.
    fn get(self: StoragePath<BitMap>, index: u256) -> bool {
        let (bucket, mask) = _bucket_and_mask(index);
        let value = self.data.read(bucket);
        !(value & mask).is_zero()
    }

    /// Sets the bit at `index` to `value`.
    fn set_to(self: StoragePath<Mutable<BitMap>>, index: u256, value: bool) {
        if value {
            self.set(index);
        } else {
            self.unset(index);
        }
    }

    /// Sets the bit at `index`.
    fn set(self: StoragePath<Mutable<BitMap>>, index: u256) {
        let (bucket, mask) = _bucket_and_mask(index);
        let value = self.data.read(bucket);
        self.data.write(bucket, value | mask);
    }

    /// Unsets the bit at `index`.
    fn unset(self: StoragePath<Mutable<BitMap>>, index: u256) {
        let (bucket, mask) = _bucket_and_mask(index);
        let value = self.data.read(bucket);
        let inverted_mask = _invert_mask(mask);
        self.data.write(bucket, value & inverted_mask);
    }
}

const _BUCKET_SIZE: u128 = 256;

fn _bucket_and_mask(index: u256) -> (u256, u256) {
    let bucket = index / _BUCKET_SIZE.into();
    let bit_index_u256 = index % _BUCKET_SIZE.into();
    // The modulo result is always < 256, so conversion to usize is safe.
    let bit_index: usize = bit_index_u256.try_into().unwrap();
    let mask = _bit_mask(bit_index);
    (bucket, mask)
}

fn _bit_mask(bit_index: usize) -> u256 {
    // Split the 256-bit word into two 128-bit halves for shifting.
    if bit_index < 128_usize {
        let low: u128 = 2_u128.pow(bit_index);
        u256 { low, high: 0 }
    } else {
        let shift = bit_index - 128;
        let high: u128 = 2_u128.pow(shift);
        u256 { low: 0, high }
    }
}

fn _invert_mask(mask: u256) -> u256 {
    let all_ones: u256 = Bounded::MAX;
    all_ones ^ mask
}
