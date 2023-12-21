// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo vX.Y.Z (account/utils/secp256k1.cairo)

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
        let (x, y) = value.get_coordinates().unwrap();

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
        let point = (*self).get_coordinates().unwrap();
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
        (*lhs).get_coordinates().unwrap() == (*rhs).get_coordinates().unwrap()
    }
    #[inline(always)]
    fn ne(lhs: @Secp256k1Point, rhs: @Secp256k1Point) -> bool {
        !(lhs == rhs)
    }
}

#[cfg(test)]
mod test {
    use starknet::secp256_trait::Secp256PointTrait;
    use starknet::secp256k1::Secp256k1Impl;
    use super::{
        SyscallResultTrait, Secp256k1Point, Secp256k1PointSerde, Secp256k1PointPartialEq,
        Secp256k1PointStorePacking as StorePacking
    };

    #[test]
    fn test_pack_big_secp256k1_points() {
        let (big_point_1, big_point_2) = get_points();
        let curve_size = Secp256k1Impl::get_curve_size();

        // Check point 1

        let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_1);
        let xhigh_and_parity: u256 = xhigh_and_parity.into();

        let x = u256 {
            low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap()
        };
        let parity = xhigh_and_parity % 2 == 1;

        assert(x == curve_size, 'Invalid x');
        assert(parity == true, 'Invalid parity');

        // Check point 2

        let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_2);
        let xhigh_and_parity: u256 = xhigh_and_parity.into();

        let x = u256 {
            low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap()
        };
        let parity = xhigh_and_parity % 2 == 1;

        assert(x == curve_size, 'Invalid x');
        assert(parity == false, 'Invalid parity');
    }

    #[test]
    fn test_unpack_big_secp256k1_points() {
        let (big_point_1, big_point_2) = get_points();
        let curve_size = Secp256k1Impl::get_curve_size();

        // Check point 1

        let (expected_x, expected_y) = big_point_1.get_coordinates().unwrap();

        let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_1);
        let (x, y) = StorePacking::unpack((xlow, xhigh_and_parity)).get_coordinates().unwrap();

        assert(x == expected_x, 'Invalid x');
        assert(y == expected_y, 'Invalid y');

        // Check point 2

        let (expected_x, expected_y) = big_point_2.get_coordinates().unwrap();

        let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_2);
        let (x, y) = StorePacking::unpack((xlow, xhigh_and_parity)).get_coordinates().unwrap();

        assert(x == expected_x, 'Invalid x');
    }

    #[test]
    fn test_secp256k1_serialization() {
        let (big_point_1, big_point_2) = get_points();
        let curve_size = Secp256k1Impl::get_curve_size();

        let mut serialized_point = array![];
        let mut expected_serialization = array![];

        // Check point 1

        big_point_1.serialize(ref serialized_point);
        big_point_1.get_coordinates().unwrap().serialize(ref expected_serialization);

        assert(serialized_point == expected_serialization, 'Invalid serialization');

        // Check point 2

        big_point_2.serialize(ref serialized_point);
        big_point_2.get_coordinates().unwrap().serialize(ref expected_serialization);

        assert(serialized_point == expected_serialization, 'Invalid serialization');
    }

    #[test]
    fn test_secp256k1_deserialization() {
        let (big_point_1, big_point_2) = get_points();
        let curve_size = Secp256k1Impl::get_curve_size();

        // Check point 1

        let mut expected_serialization = array![];

        big_point_1.get_coordinates().unwrap().serialize(ref expected_serialization);
        let mut expected_serialization = expected_serialization.span();
        let deserialized_point = Secp256k1PointSerde::deserialize(ref expected_serialization)
            .unwrap();

        assert(big_point_1 == deserialized_point, 'Invalid deserialization');

        // Check point 2

        let mut expected_serialization = array![];

        big_point_2.get_coordinates().unwrap().serialize(ref expected_serialization);
        let mut expected_serialization = expected_serialization.span();
        let deserialized_point = Secp256k1PointSerde::deserialize(ref expected_serialization)
            .unwrap();

        assert(big_point_2 == deserialized_point, 'Invalid deserialization');
    }

    #[test]
    fn test_partial_eq() {
        let (big_point_1, big_point_2) = get_points();

        assert(big_point_1 == big_point_1, 'Invalid equality');
        assert(big_point_2 == big_point_2, 'Invalid equality');
        assert(big_point_1 != big_point_2, 'Invalid equality');
        assert(big_point_2 != big_point_1, 'Invalid equality');
    }

    //
    // Helpers
    //

    fn get_points() -> (Secp256k1Point, Secp256k1Point) {
        let curve_size = Secp256k1Impl::get_curve_size();
        let point_1 = Secp256k1Impl::secp256_ec_get_point_from_x_syscall(curve_size, true)
            .unwrap_syscall()
            .unwrap();
        let point_2 = Secp256k1Impl::secp256_ec_get_point_from_x_syscall(curve_size, false)
            .unwrap_syscall()
            .unwrap();

        (point_1, point_2)
    }
}
