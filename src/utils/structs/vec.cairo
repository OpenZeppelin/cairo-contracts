use dict::Felt252DictTrait;
use option::OptionTrait;
use traits::{Index, Into};

/// Generic felt-indexed vector.
struct Vec<T> {
    items: Felt252Dict<T>,
    len: usize,
}

trait VecTrait<V, T> {
    fn new() -> V;
    fn get(ref self: V, index: usize) -> Option<T>;
    fn at(ref self: V, index: usize) -> T;
    fn push(ref self: V, value: T) -> ();
    fn set(ref self: V, index: usize, value: T);
    fn len(self: @V) -> usize;
}

impl VecImpl<
    T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TFelt252DictValue: Felt252DictValue<T>
> of VecTrait<Vec<T>, T> {
    fn new() -> Vec<T> {
        Vec { items: Default::default(), len: 0 }
    }

    fn get(ref self: Vec<T>, index: usize) -> Option<T> {
        if index < self.len() {
            let item = self.items.get(index.into());
            Option::Some(item)
        } else {
            Option::None(())
        }
    }

    fn at(ref self: Vec<T>, index: usize) -> T {
        assert(index < self.len(), 'Index out of bounds');
        let item = self.items.get(index.into());
        item
    }

    fn push(ref self: Vec<T>, value: T) -> () {
        self.items.insert(self.len.into(), value);
        self.len = integer::u32_wrapping_add(self.len, 1_usize);
    }

    fn set(ref self: Vec<T>, index: usize, value: T) {
        assert(index < self.len(), 'Index out of bounds');
        self.items.insert(index.into(), value);
    }

    fn len(self: @Vec<T>) -> usize {
        *self.len
    }
}

impl VecIndex<V, T, impl TVecTrait: VecTrait<V, T>> of Index<V, usize, T> {
    #[inline(always)]
    fn index(ref self: V, index: usize) -> T {
        self.at(index)
    }
}

impl DestructVec<
    T, impl TDrop: Drop<T>, impl TFelt252DictValue: Felt252DictValue<T>
> of Destruct<Vec<T>> {
    fn destruct(self: Vec<T>) nopanic {
        self.items.squash();
    }
}
