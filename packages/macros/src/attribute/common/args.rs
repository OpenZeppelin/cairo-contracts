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
    // Track `<...>` conservatively: only delimiters attached to identifier-like tokens are
    // treated as generics. This prefers avoiding false positives for comparison operators over
    // accepting every whitespace-heavy generic spelling.
    let mut angle_depth = 0usize;
    let mut in_string = false;
    let mut last_non_whitespace = None;

    for (index, ch) in s.char_indices() {
        if ch == '"' && !quote_is_escaped(s, index) {
            in_string = !in_string;
        } else if !in_string {
            match ch {
                '(' => paren_depth += 1,
                ')' => paren_depth = paren_depth.checked_sub(1)?,
                '<' if opens_generic_arguments(s, index, last_non_whitespace) => angle_depth += 1,
                '>' if angle_depth > 0 => angle_depth -= 1,
                ',' if paren_depth == 0 && angle_depth == 0 => {
                    parts.push(s[start..index].trim());
                    start = index + ch.len_utf8();
                }
                _ => {}
            }

            if !ch.is_whitespace() {
                last_non_whitespace = Some(ch);
            }
        }
    }

    if in_string || paren_depth != 0 || angle_depth != 0 {
        return None;
    }

    parts.push(s[start..].trim());
    Some(parts)
}

fn quote_is_escaped(s: &str, quote_index: usize) -> bool {
    s[..quote_index]
        .chars()
        .rev()
        .take_while(|&ch| ch == '\\')
        .count()
        % 2
        == 1
}

fn opens_generic_arguments(s: &str, index: usize, previous_non_whitespace: Option<char>) -> bool {
    s[..index]
        .chars()
        .next_back()
        .is_some_and(|ch| !ch.is_whitespace())
        && matches!(
            previous_non_whitespace,
            Some(ch)
                if ch.is_ascii_alphanumeric() || ch == '_' || matches!(ch, ')' | ']' | '>' | ':')
        )
}

#[cfg(test)]
mod tests {
    use super::split_top_level_args;

    #[test]
    fn splits_args_when_string_ends_with_escaped_backslash() {
        let parts = split_top_level_args(r#"name: "test\\", debug: true"#).unwrap();
        assert_eq!(parts, vec![r#"name: "test\\""#, "debug: true"]);
    }
}
