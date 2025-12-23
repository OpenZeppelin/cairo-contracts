use crate::constants::TAB;

/// Generates a string with `n` tabs.
pub fn tabs(n: usize) -> String {
    TAB.repeat(n)
}

/// Converts a camelCase string to a snake_case string.
pub fn camel_to_snake(input: &str) -> String {
    let mut snake = String::with_capacity(input.len());

    for (i, ch) in input.chars().enumerate() {
        if ch.is_uppercase() {
            if i != 0 {
                snake.push('_');
            }
            for lc in ch.to_lowercase() {
                snake.push(lc);
            }
        } else {
            snake.push(ch);
        }
    }

    snake
}
