use crate::constants::TAB;
use std::iter::repeat;

/// Generates a string with `n` tabs.
pub fn tabs(n: usize) -> String {
    repeat(TAB).take(n).collect()
}
