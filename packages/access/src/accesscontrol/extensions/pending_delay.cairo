// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v2.0.0-alpha.1
// (access/src/accesscontrol/extensions/pending_delay.cairo)

use starknet::storage_access::StorePacking;

/// Information about a scheduledpending delay.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct PendingDelay {
    pub delay: u64,
    pub schedule: u64 // 0 if not scheduled
}

const _2_POW_64: felt252 = 0x10000000000000000;

/// Packs an PendingDelay into a single felt252.
///
/// The packing is done as follows:
///
/// 1. `delay` is stored at range [124,187] (0-indexed starting from the most significant bits).
/// 2. `schedule` is stored at range [188, 251], following `delay`.
impl PendingDelayStorePacking of StorePacking<PendingDelay, felt252> {
    fn pack(value: PendingDelay) -> felt252 {
        let PendingDelay { delay, schedule } = value;
        let delay_with_offset = delay.into() * _2_POW_64;

        delay_with_offset + schedule.into()
    }

    fn unpack(value: felt252) -> PendingDelay {
        let value: u256 = value.into();
        let delay = value / _2_POW_64.into();
        let schedule = value % _2_POW_64.into();

        // It is safe to unwrap because the two values were packed from u64 integers
        PendingDelay { delay: delay.try_into().unwrap(), schedule: schedule.try_into().unwrap() }
    }
}

#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use super::{PendingDelay, PendingDelayStorePacking};

    #[test]
    fn test_pack_and_unpack() {
        let pending_delay = PendingDelay { delay: 100, schedule: 200 };
        let packed = PendingDelayStorePacking::pack(pending_delay);
        let unpacked = PendingDelayStorePacking::unpack(packed);
        assert_eq!(pending_delay, unpacked);
    }

    #[test]
    fn test_pack_and_unpack_big_values() {
        let pending_delay = PendingDelay { delay: Bounded::MAX, schedule: Bounded::MAX };
        let packed = PendingDelayStorePacking::pack(pending_delay);
        let unpacked = PendingDelayStorePacking::unpack(packed);
        assert_eq!(pending_delay, unpacked);
    }
}
