// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/zq.cairo)

//! Arithmetic helpers for `Z_q`, where `q = 12289`.
//!
//! Modular operands are canonical `u16` values in `[0, Q)`. The modular helpers return canonical
//! residues, while the norm helpers return squared centered representatives. All intermediate
//! values fit their declared types.

/// The Falcon modulus `q = 12289 = 12 · 1024 + 1`.
pub const Q: u16 = 12289;
pub const Q32: u32 = 12289;

/// Largest centered-low value: `(Q - 1) / 2`. Coefficients above this represent negatives.
pub const Q_HALF: u16 = 6144;

/// Adds two values modulo `Q`.
#[cfg(test)]
#[inline(always)]
pub fn add_mod(a: u16, b: u16) -> u16 {
    // a, b < Q so a + b <= 24576 < 2^16: the checked u16 add never overflows, and a
    // single conditional subtraction reduces the sum.
    let d = a + b;
    if d >= Q {
        d - Q
    } else {
        d
    }
}

/// Subtracts two values modulo `Q` via `a + Q - b` and one conditional subtraction.
#[cfg(test)]
#[inline(always)]
pub fn sub_mod(a: u16, b: u16) -> u16 {
    // a < Q so a + Q <= 24577 < 2^16; a + Q - b is in [1, 2Q-1].
    let d = a + Q - b;
    if d >= Q {
        d - Q
    } else {
        d
    }
}

/// Multiplies two values modulo `Q`.
#[cfg(test)]
#[inline(always)]
pub fn mul_mod(a: u16, b: u16) -> u16 {
    let a: u32 = a.into();
    let b: u32 = b.into();
    // a·b <= 12288² < 2^31.
    let res = (a * b) % Q32;
    res.try_into().unwrap()
}

/// Squared centered representative of a coefficient as `felt252`:
/// x ∈ [0, 6144] → x²; x ∈ [6145, 12288] → (Q - x)².
#[inline(always)]
pub fn center_sq(coeff: u16) -> felt252 {
    if coeff <= Q_HALF {
        let x: felt252 = coeff.into();
        x * x
    } else {
        let x: felt252 = (Q - coeff).into();
        x * x
    }
}

/// Squared centered representative of `a - b` for canonical coefficients.
#[inline(always)]
pub(crate) fn centered_difference_sq(a: u16, b: u16) -> felt252 {
    let difference = if a >= b {
        a - b
    } else {
        b - a
    };
    let centered = if difference <= Q_HALF {
        difference
    } else {
        Q - difference
    };
    let centered: felt252 = centered.into();
    centered * centered
}

#[cfg(test)]
mod tests {
    use super::{Q, add_mod, center_sq, centered_difference_sq, mul_mod, sub_mod};

    #[test]
    fn test_add_mod_wraps() {
        assert_eq!(add_mod(12288, 1), 0);
        assert_eq!(add_mod(12288, 12288), 12287); // (-1) + (-1) = -2 = q - 2
        assert_eq!(add_mod(0, 0), 0);
    }

    #[test]
    fn test_sub_mod_wraps() {
        assert_eq!(sub_mod(0, 1), 12288);
        assert_eq!(sub_mod(1, 1), 0);
        assert_eq!(sub_mod(12288, 12287), 1);
    }

    #[test]
    fn test_mul_mod() {
        assert_eq!(mul_mod(12288, 12288), 1); // (-1)² = 1
        assert_eq!(mul_mod(0, 12288), 0);
        // SQR1 = 1479 is a square root of -1 mod q
        assert_eq!(mul_mod(1479, 1479), Q - 1);
        // 2 · 6145 = 12290 = 1 mod q (6145 = 2⁻¹)
        assert_eq!(mul_mod(2, 6145), 1);
    }

    #[test]
    fn test_center_sq() {
        assert_eq!(center_sq(0), 0);
        assert_eq!(center_sq(1), 1);
        assert_eq!(center_sq(6144), 6144 * 6144); // largest low-half value
        assert_eq!(center_sq(6145), 6144 * 6144); // q - 6145 = 6144
        assert_eq!(center_sq(12288), 1); // -1 centered is ±1
    }

    #[test]
    fn test_centered_difference_sq_boundaries_and_equivalence() {
        assert_eq!(centered_difference_sq(0, 0), 0);
        assert_eq!(centered_difference_sq(0, 1), 1);
        assert_eq!(centered_difference_sq(1, 0), 1);
        assert_eq!(centered_difference_sq(0, 6144), 6144 * 6144);
        assert_eq!(centered_difference_sq(0, 6145), 6144 * 6144);
        assert_eq!(centered_difference_sq(0, 12288), 1);
        assert_eq!(centered_difference_sq(12288, 0), 1);

        let boundaries: [u16; 7] = [0, 1, 6143, 6144, 6145, 12287, 12288];
        for a in boundaries.span() {
            for b in boundaries.span() {
                assert_eq!(centered_difference_sq(*a, *b), center_sq(sub_mod(*a, *b)));
            }
        }
    }
}
