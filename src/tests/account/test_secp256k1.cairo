use openzeppelin::account::utils::secp256k1::{
    SyscallResultTrait, Secp256k1Point, DebugSecp256k1Point, Secp256k1PointSerde,
    Secp256k1PointPartialEq, Secp256k1PointStorePacking as StorePacking
};
use starknet::secp256_trait::Secp256PointTrait;
use starknet::secp256k1::Secp256k1Impl;

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

    assert_eq!(x, curve_size);
    assert_eq!(parity, true, "Parity should be odd");

    // Check point 2

    let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_2);
    let xhigh_and_parity: u256 = xhigh_and_parity.into();

    let x = u256 {
        low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap()
    };
    let parity = xhigh_and_parity % 2 == 1;

    assert_eq!(x, curve_size);
    assert_eq!(parity, false, "Parity should be even");
}

#[test]
fn test_unpack_big_secp256k1_points() {
    let (big_point_1, big_point_2) = get_points();

    // Check point 1

    let (expected_x, expected_y) = big_point_1.get_coordinates().unwrap_syscall();

    let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_1);
    let (x, y) = StorePacking::unpack((xlow, xhigh_and_parity)).get_coordinates().unwrap_syscall();

    assert_eq!(x, expected_x);
    assert_eq!(y, expected_y);

    // Check point 2

    let (expected_x, _) = big_point_2.get_coordinates().unwrap_syscall();

    let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_2);
    let (x, _) = StorePacking::unpack((xlow, xhigh_and_parity)).get_coordinates().unwrap_syscall();

    assert_eq!(x, expected_x);
}

#[test]
fn test_secp256k1_serialization() {
    let (big_point_1, big_point_2) = get_points();

    let mut serialized_point = array![];
    let mut expected_serialization = array![];

    // Check point 1

    big_point_1.serialize(ref serialized_point);
    big_point_1.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);

    assert!(serialized_point == expected_serialization);

    // Check point 2

    big_point_2.serialize(ref serialized_point);
    big_point_2.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);

    assert!(serialized_point == expected_serialization);
}

#[test]
fn test_secp256k1_deserialization() {
    let (big_point_1, big_point_2) = get_points();

    // Check point 1

    let mut expected_serialization = array![];

    big_point_1.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);
    let mut expected_serialization = expected_serialization.span();
    let deserialized_point = Secp256k1PointSerde::deserialize(ref expected_serialization).unwrap();

    assert_eq!(big_point_1, deserialized_point);

    // Check point 2

    let mut expected_serialization = array![];

    big_point_2.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);
    let mut expected_serialization = expected_serialization.span();
    let deserialized_point = Secp256k1PointSerde::deserialize(ref expected_serialization).unwrap();

    assert_eq!(big_point_2, deserialized_point);
}

#[test]
fn test_partial_eq() {
    let (big_point_1, big_point_2) = get_points();

    assert_eq!(big_point_1, big_point_1);
    assert_eq!(big_point_2, big_point_2);
    assert!(big_point_1 != big_point_2);
    assert!(big_point_2 != big_point_1);
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
