// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (utils/structs/double_ended_queue.cairo)

use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
use starknet::storage::{StoragePath, Mutable};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

/// A sequence with the ability to efficiently push and pop items (i.e. insert and remove) on both
/// ends of the sequence (called front and back). Among other access patterns, it can be used to
/// implement efficient LIFO and FIFO queues. All operations are O(1) constant time. This includes
/// ´clear´, given that the existing queue contents are left in storage.
///
/// NOTE: This is a phantom type which can only be used in storage, and members are only accessible
/// through the ´DoubleEndedQueueTrait´ implementation.
#[starknet::storage_node]
pub struct DoubleEndedQueue {
    pub(crate) _begin: felt252,
    pub(crate) _end: felt252,
    pub(crate) _data: Map<felt252, felt252>
}

pub mod DoubleEndedQueueErrors {
    pub const FULL_QUEUE: felt252 = 'Queue: full queue';
    pub const EMPTY_QUEUE: felt252 = 'Queue: empty queue';
}

#[generate_trait]
pub impl DoubleEndedQueueImpl of DoubleEndedQueueTrait {
    /// Inserts an item at the end of the queue.
    fn push_back(self: StoragePath<Mutable<DoubleEndedQueue>>, value: felt252) {
        let back_index = self._end.read();
        assert(back_index + 1 != self._begin.read(), DoubleEndedQueueErrors::FULL_QUEUE);
        self._data.write(back_index, value);
        self._end.write(back_index + 1);
    }

    /// Removes the item at the end of the queue and returns it.
    fn pop_back(self: StoragePath<Mutable<DoubleEndedQueue>>) -> felt252 {
        let mut back_index = self._end.read();
        assert(back_index != self._begin.read(), DoubleEndedQueueErrors::EMPTY_QUEUE);
        back_index -= 1;
        let value = self._data.read(back_index);
        self._data.write(back_index, 0);
        self._end.write(back_index);
        value
    }

    /// Inserts an item at the beginning of the queue.
    fn push_front(self: StoragePath<Mutable<DoubleEndedQueue>>, value: felt252) {
        let front_index = self._begin.read() - 1;
        assert(front_index != self._end.read(), DoubleEndedQueueErrors::FULL_QUEUE);
        self._data.write(front_index, value);
        self._begin.write(front_index);
    }

    /// Removes the item at the beginning of the queue and returns it.
    fn pop_front(self: StoragePath<Mutable<DoubleEndedQueue>>) -> felt252 {
        let front_index = self._begin.read();
        assert(front_index != self._end.read(), DoubleEndedQueueErrors::EMPTY_QUEUE);
        let value = self._data.read(front_index);
        self._data.write(front_index, 0);
        self._begin.write(front_index + 1);
        value
    }

    /// Resets the queue back to being empty.
    ///
    /// NOTE: The current items are left behind in storage. This does not affect the functioning
    /// of the queue.
    fn clear(self: StoragePath<Mutable<DoubleEndedQueue>>) {
        self._begin.write(0);
        self._end.write(0);
    }

    /// Returns the item at the beginning of the queue.
    fn front(self: StoragePath<DoubleEndedQueue>) -> felt252 {
        assert(!self.is_empty(), DoubleEndedQueueErrors::EMPTY_QUEUE);
        self._data.read(self._begin.read())
    }

    /// Returns the item at the end of the queue.
    fn back(self: StoragePath<DoubleEndedQueue>) -> felt252 {
        assert(!self.is_empty(), DoubleEndedQueueErrors::EMPTY_QUEUE);
        self._data.read(self._end.read() - 1)
    }

    /// Returns the number of items in the queue.
    fn len(self: StoragePath<DoubleEndedQueue>) -> felt252 {
        self._end.read() - self._begin.read()
    }

    /// Returns true if the queue is empty.
    fn is_empty(self: StoragePath<DoubleEndedQueue>) -> bool {
        self._begin.read() == self._end.read()
    }
}
