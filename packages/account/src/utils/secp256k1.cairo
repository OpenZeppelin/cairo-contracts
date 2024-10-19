// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (account/utils/secp256k1.cairo)

use core::fmt::{Formatter, Error};
use starknet::SyscallResultTrait;
use starknet::secp256_trait::{Secp256Trait, Secp256PointTrait};
use starknet::secp256k1::Secp256k1Point;
use starknet::storage_access::StorePacking;

/// Packs a Secp256k1Point into a (felt252, felt252).
///
/// The packing is done as follows:
/// - First felt contains x.low (x being the x-coordinate of the point).
/// - Second felt contains x.high and the parity bit, at the least significant bits (2 * x.high +
/// parity).
pub impl Secp256k1PointStorePacking of StorePacking<Secp256k1Point, (felt252, felt252)> {
    fn pack(value: Secp256k1Point) -> (felt252, felt252) {
        let (x, y) = value.get_coordinates().unwrap_syscall();

        let parity = y % 2;
        let xhigh_and_parity = 2 * x.high.into() + parity.try_into().unwrap();

        (x.low.into(), xhigh_and_parity)
    }

    fn unpack(value: (felt252, felt252)) -> Secp256k1Point {
        let (xlow, xhigh_and_parity) = value;
        let xhigh_and_parity: u256 = xhigh_and_parity.into();

        let x = u256 {
            low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap(),
        };
        let parity = xhigh_and_parity % 2 == 1;

        // Expects parity odd to be true
        Secp256Trait::secp256_ec_get_point_from_x_syscall(x, parity)
            .unwrap_syscall()
            .expect('Secp256k1Point: Invalid point.')
    }
}

pub impl Secp256k1PointPartialEq of PartialEq<Secp256k1Point> {
    #[inline(always)]
    fn eq(lhs: @Secp256k1Point, rhs: @Secp256k1Point) -> bool {
        (*lhs).get_coordinates().unwrap_syscall() == (*rhs).get_coordinates().unwrap_syscall()
    }
    #[inline(always)]
    fn ne(lhs: @Secp256k1Point, rhs: @Secp256k1Point) -> bool {
        !(lhs == rhs)
    }
}

pub impl DebugSecp256k1Point of core::fmt::Debug<Secp256k1Point> {
    fn fmt(self: @Secp256k1Point, ref f: Formatter) -> Result<(), Error> {
        let (x, y) = (*self).get_coordinates().unwrap_syscall();
        write!(f, "({x:?},{y:?})")
    }
}
