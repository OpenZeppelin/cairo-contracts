// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (account/utils/secp256k1.cairo)

use core::fmt::{Debug, Formatter, Error};
use starknet::SyscallResultTrait;
use starknet::secp256_trait::Secp256PointTrait;
use starknet::secp256k1::{
    Secp256k1Point, secp256k1_get_point_from_x_syscall, secp256k1_new_syscall
};

/// Packs a Secp256k1Point into a (felt252, felt252).
///
/// The packing is done as follows:
/// - First felt contains x.low (x being the x-coordinate of the point).
/// - Second felt contains x.high and the parity bit, at the least significant bits (2 * x.high + parity).
impl Secp256k1PointStorePacking of starknet::StorePacking<Secp256k1Point, (felt252, felt252)> {
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
        secp256k1_get_point_from_x_syscall(x, parity)
            .unwrap_syscall()
            .expect('Secp256k1Point: Invalid point.')
    }
}

impl Secp256k1PointSerde of Serde<Secp256k1Point> {
    fn serialize(self: @Secp256k1Point, ref output: Array<felt252>) {
        let point = (*self).get_coordinates().unwrap_syscall();
        point.serialize(ref output)
    }
    fn deserialize(ref serialized: Span<felt252>) -> Option<Secp256k1Point> {
        let (x, y) = Serde::<(u256, u256)>::deserialize(ref serialized)?;
        secp256k1_new_syscall(x, y).unwrap_syscall()
    }
}

impl Secp256k1PointPartialEq of PartialEq<Secp256k1Point> {
    #[inline(always)]
    fn eq(lhs: @Secp256k1Point, rhs: @Secp256k1Point) -> bool {
        (*lhs).get_coordinates().unwrap_syscall() == (*rhs).get_coordinates().unwrap_syscall()
    }
    #[inline(always)]
    fn ne(lhs: @Secp256k1Point, rhs: @Secp256k1Point) -> bool {
        !(lhs == rhs)
    }
}

impl DebugSecp256k1Point of core::fmt::Debug<Secp256k1Point> {
    fn fmt(self: @Secp256k1Point, ref f: Formatter) -> Result<(), Error> {
        let (x, y) = (*self).get_coordinates().unwrap_syscall();
        write!(f, "({x:?},{y:?})")
    }
}
