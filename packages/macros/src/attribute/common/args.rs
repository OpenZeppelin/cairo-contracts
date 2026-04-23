//! Lightweight parsers for procedural macro attribute arguments.
//!
//! Attribute token streams stringify to Cairo source, but simple `split(',')` parsing breaks as
//! soon as an argument contains a tuple, generic type, or string with a comma. These helpers keep
//! that low-level scanning in one place and leave each macro entry point to validate its own keys
//! and values.

/// Splits a comma-separated argument list, ignoring commas inside strings, tuples, and generic
/// type expressions.
///
/// Returns `None` if the argument list has unbalanced delimiters or an unterminated string.
pub fn split_top_level_args(s: &str) -> Option<Vec<&str>> {
    let mut parts = vec![];
    let mut start = 0;
    let mut paren_depth = 0usize;
    let mut angle_depth = 0usize;
    let mut in_string = false;
    let mut previous = None;

    for (index, ch) in s.char_indices() {
        if ch == '"' && previous != Some('\\') {
            in_string = !in_string;
        } else if !in_string {
            match ch {
                '(' => paren_depth += 1,
                ')' => paren_depth = paren_depth.checked_sub(1)?,
                '<' => angle_depth += 1,
                '>' => angle_depth = angle_depth.checked_sub(1)?,
                ',' if paren_depth == 0 && angle_depth == 0 => {
                    parts.push(s[start..index].trim());
                    start = index + ch.len_utf8();
                }
                _ => {}
            }
        }
        previous = Some(ch);
    }

    if in_string || paren_depth != 0 || angle_depth != 0 {
        return None;
    }

    parts.push(s[start..].trim());
    Some(parts)
}
