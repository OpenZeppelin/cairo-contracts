use integer::u32_sqrt;
use openzeppelin::utils::math;
use super::storage_array::StorageArrayTrait;
use super::storage_array::StorageArray;
use traits::Into;

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block number. See {Votes} as an example.
#[derive(Copy, Drop, starknet::Store)]
struct Trace {
    checkpoints: StorageArray<Checkpoint>
}

/// Generic checkpoint representation.
#[derive(Copy, Drop, starknet::Store)]
struct Checkpoint {
    key: u32,
    // TODO: Check if is worth implementing a u220 type in corelib for saving gas by packing.
    // Maybe is worth using u128 specifically for the fee token, if the token has just 6 decimals.
    value: u256
}

#[generate_trait]
impl TraceImpl of TraceTrait {
    /// Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.
    ///
    /// Returns previous value and new value.
    fn push(ref self: Trace, key: u32, value: u256) -> (u256, u256) {
        self.checkpoints._insert(key, value)
    }

    /// Returns the value in the first (oldest) checkpoint with key greater or equal
    /// than the search key, or zero if there is none.
    fn lower_lookup(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self.checkpoints;
        let len = checkpoints.len();
        let pos = checkpoints._lower_binary_lookup(key, 0, len);

        if pos == len {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(pos);
            checkpoint.value
        }
    }

    /// Returns the value in the last (most recent) checkpoint with key lower or equal
    /// than the search key, or zero if there is none.
    fn upper_lookup(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self.checkpoints;
        let len = checkpoints.len();
        let pos = checkpoints._upper_binary_lookup(key, 0, len);

        if pos == len {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(pos - 1);
            checkpoint.value
        }
    }

    /// Returns the value in the last (most recent) checkpoint with key lower or equal
    /// than the search key, or zero if there is none.
    ///
    /// NOTE: This is a variant of {upper_lookup} that is optimised to
    /// find "recent" checkpoint (checkpoints with high keys).
    fn upper_lookup_recent(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self.checkpoints;
        let len = checkpoints.len();

        let mut low = 0;
        let mut high = len;

        if (len > 5) {
            let mid = len - u32_sqrt(len).into();
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(mid);
            if (key < checkpoint.key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        let pos = checkpoints._upper_binary_lookup(key, low, high);

        if pos == len {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(pos - 1);
            checkpoint.value
        }
    }

    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: Trace) -> u256 {
        let mut checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(pos - 1);
            checkpoint.value
        }
    }

    /// Returns whether there is a checkpoint in the structure (i.e. it is not empty),
    /// and if so the key and value in the most recent checkpoint.
    fn latest_checkpoint(self: Trace) -> (bool, u32, u256) {
        let mut checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if (pos == 0) {
            (false, 0, 0)
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.read_at(pos - 1);
            (true, checkpoint.key, checkpoint.value)
        }
    }

    /// Returns the number of checkpoints.
    fn length(self: @Trace) -> u32 {
        self.checkpoints.len()
    }

    /// Returns the checkpoint at given position.
    fn at(self: Trace, pos: u32) -> Checkpoint {
        let mut checkpoints = self.checkpoints;
        checkpoints.read_at(pos)
    }
}

#[generate_trait]
impl CheckpointImpl of CheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
    /// or by updating the last one.
    fn _insert(ref self: StorageArray<Checkpoint>, key: u32, value: u256) -> (u256, u256) {
        let pos = self.len();

        if (pos > 0) {
            let mut last: Checkpoint = self.read_at(pos - 1);

            // Checkpoint keys must be non-decreasing.
            assert(last.key <= key, 'Unordered insertion');

            // Update or append new checkpoint.
            let prev = last.value;
            if (last.key == key) {
                last.value = value;
                self.write_at(pos - 1, last);
            } else {
                self.append(Checkpoint { key: key, value: value });
            }
            (prev, value)
        } else {
            self.append(Checkpoint { key: key, value: value });
            (0, value)
        }
    }

    /// Return the index of the last (most recent) checkpoint with key lower or equal than the search key,
    /// or `high` if there is none. `low` and `high` define a section where to do the search, with
    /// inclusive `low` and exclusive `high`.
    fn _upper_binary_lookup(
        ref self: StorageArray<Checkpoint>, key: u32, low: u32, high: u32
    ) -> u32 {
        let mut _low = low;
        let mut _high = high;
        loop {
            if _low >= _high {
                break;
            }
            let mid = math::average(_low, _high);
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = self.read_at(mid);
            if (checkpoint.key > key) {
                _high = mid;
            } else {
                _low = mid + 1;
            };
        };
        _high
    }

    /// Return the index of the first (oldest) checkpoint with key is greater or equal than the search key,
    /// or `high` if there is none. `low` and `high` define a section where to do the search, with
    /// inclusive `low` and exclusive `high`.
    fn _lower_binary_lookup(
        ref self: StorageArray<Checkpoint>, key: u32, low: u32, high: u32
    ) -> u32 {
        let mut _low = low;
        let mut _high = high;
        loop {
            if _low >= _high {
                break;
            }
            let mid = math::average(_low, _high);
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = self.read_at(mid);
            if (checkpoint.key < key) {
                _low = mid + 1;
            } else {
                _high = mid;
            };
        };
        high
    }
}
