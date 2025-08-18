// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.1
// (access/src/accesscontrol/extensions/pending_delay.cairo)

use core::integer::u128_safe_divmod;
use starknet::storage_access::StorePacking;

/// Information about a scheduledpending delay.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct PendingDelay {
    pub delay: u64,
    pub schedule: u64 // 0 if not scheduled
}

const _2_POW_64: NonZero<u128> = 0x10000000000000000;

/// Packs an PendingDelay into a single u128.
///
/// The packing is done as follows:
///
/// 1. `delay` is stored at range [0,63] (0-indexed starting from the most significant bits).
/// 2. `schedule` is stored at range [64, 127], following `delay`.
impl PendingDelayStorePacking of StorePacking<PendingDelay, u128> {
    fn pack(value: PendingDelay) -> u128 {
        let PendingDelay { delay, schedule } = value;
        let delay_with_offset = delay.into() * _2_POW_64.into();

        delay_with_offset + schedule.into()
    }

    fn unpack(value: u128) -> PendingDelay {
        let (delay, schedule) = u128_safe_divmod(value, _2_POW_64);

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

    #[test]
    #[fuzzer]
    fn test_pack_and_unpack_fuzz(delay: u64, schedule: u64) {
        let pending_delay = PendingDelay { delay, schedule };
        let packed_value = PendingDelayStorePacking::pack(pending_delay);
        let unpacked_info = PendingDelayStorePacking::unpack(packed_value);

        assert_eq!(unpacked_info.delay, delay);
        assert_eq!(unpacked_info.schedule, schedule);
    }
}
