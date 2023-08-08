use integer::u32_sqrt;
use openzeppelin::utils::math;
use starknet::Store;
use super::vec::VecTrait;
use super::vec::Vec;
use traits::Into;

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block number. See {Votes} as an example.
struct Trace {
    _checkpoints: Vec<Checkpoint>
}

/// Generic checkpoint representation.
#[derive(Copy, Drop)]
struct Checkpoint {
    _key: u32,
    // TODO: Check if is worth implementing a u220 type in corelib for saving gas by packing.
    // Maybe is worth using u128 specifically for the fee token, if the token has just 6 decimals.
    _value: u256
}

#[generate_trait]
impl TraceImpl of TraceTrait {
    /// Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.
    ///
    /// Returns previous value and new value.
    fn push(ref self: Trace, key: u32, value: u256) -> (u256, u256) {
        self._checkpoints._insert(key, value)
    }

    /// Returns the value in the first (oldest) checkpoint with key greater or equal
    /// than the search key, or zero if there is none.
    fn lower_lookup(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self._checkpoints;
        let len = checkpoints.len();
        let pos = checkpoints._lower_binary_lookup(key, 0, len);

        if pos == len {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.at(pos);
            checkpoint._value
        }
    }

    /// Returns the value in the last (most recent) checkpoint with key lower or equal
    /// than the search key, or zero if there is none.
    fn upper_lookup(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self._checkpoints;
        let len = checkpoints.len();
        let pos = checkpoints._upper_binary_lookup(key, 0, len);

        if pos == len {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.at(pos - 1);
            checkpoint._value
        }
    }

    /// Returns the value in the last (most recent) checkpoint with key lower or equal
    /// than the search key, or zero if there is none.
    ///
    /// NOTE: This is a variant of {upper_lookup} that is optimised to
    /// find "recent" checkpoint (checkpoints with high keys).
    fn upper_lookup_recent(self: Trace, key: u32) -> u256 {
        let mut checkpoints = self._checkpoints;
        let len = checkpoints.len();

        let mut low = 0;
        let mut high = len;

        if (len > 5) {
            let mid = len - u32_sqrt(len).into();
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.at(mid);
            if (key < checkpoint._key) {
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
            let checkpoint: Checkpoint = checkpoints.at(pos - 1);
            checkpoint._value
        }
    }

    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: Trace) -> u256 {
        let mut checkpoints = self._checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            0
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.at(pos - 1);
            checkpoint._value
        }
    }

    /// Returns whether there is a checkpoint in the structure (i.e. it is not empty),
    /// and if so the key and value in the most recent checkpoint.
    fn latest_checkpoint(self: Trace) -> (bool, u32, u256) {
        let mut checkpoints = self._checkpoints;
        let pos = checkpoints.len();

        if (pos == 0) {
            (false, 0, 0)
        } else {
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = checkpoints.at(pos - 1);
            (true, checkpoint._key, checkpoint._value)
        }
    }

    /// Returns the number of checkpoints.
    fn length(self: @Trace) -> u32 {
        self._checkpoints.len()
    }

    /// Returns the checkpoint at given position.
    fn at(self: Trace, pos: u32) -> Checkpoint {
        let mut checkpoints = self._checkpoints;
        checkpoints.at(pos)
    }
}

#[generate_trait]
impl CheckpointImpl of CheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
    /// or by updating the last one.
    fn _insert(ref self: Vec<Checkpoint>, key: u32, value: u256) -> (u256, u256) {
        let pos = self.len();

        if (pos > 0) {
            let mut last: Checkpoint = self.at(pos - 1);

            // Checkpoint keys must be non-decreasing.
            assert(last._key <= key, 'Unordered insertion');

            // Update or push new checkpoint
            let prev = last._value;
            if (last._key == key) {
                last._value = value;
                self.set(pos - 1, last);
            } else {
                self.push(Checkpoint { _key: key, _value: value });
            }
            (prev, value)
        } else {
            self.push(Checkpoint { _key: key, _value: value });
            (0, value)
        }
    }

    /// Return the index of the last (most recent) checkpoint with key lower or equal than the search key,
    /// or `high` if there is none. `low` and `high` define a section where to do the search, with
    /// inclusive `low` and exclusive `high`.
    fn _upper_binary_lookup(ref self: Vec<Checkpoint>, key: u32, low: u32, high: u32) -> u32 {
        let mut _low = low;
        let mut _high = high;
        loop {
            if _low >= _high {
                break;
            }
            let mid = math::average(_low, _high);
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = self.at(mid);
            if (checkpoint._key > key) {
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
    fn _lower_binary_lookup(ref self: Vec<Checkpoint>, key: u32, low: u32, high: u32) -> u32 {
        let mut _low = low;
        let mut _high = high;
        loop {
            if _low >= _high {
                break;
            }
            let mid = math::average(_low, _high);
            /// TODO: Check why it fails to infer the Checkpoint type directly
            let checkpoint: Checkpoint = self.at(mid);
            if (checkpoint._key < key) {
                _low = mid + 1;
            } else {
                _high = mid;
            };
        };
        high
    }
}

/// Default values for felt252_dict values.
impl CheckpointFelt252DictValue of Felt252DictValue<Checkpoint> {
    #[inline(always)]
    fn zero_default() -> Checkpoint nopanic {
        Checkpoint { _key: 0, _value: 0 }
    }
}
