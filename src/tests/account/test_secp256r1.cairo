use openzeppelin::account::utils::secp256r1::{
    SyscallResultTrait, Secp256r1Point, DebugSecp256r1Point, Secp256r1PointSerde,
    Secp256r1PointPartialEq, Secp256r1PointStorePacking as StorePacking, secp256r1_new_syscall
};
use starknet::secp256_trait::Secp256PointTrait;
use starknet::secp256r1::Secp256r1Impl;

#[test]
fn test_curve_size() {
    let curve_size = Secp256r1Impl::get_curve_size();
    assert_eq!(curve_size, 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551);
    assert_eq!(curve_size.low, 0xbce6faada7179e84f3b9cac2fc632551);
    assert_eq!(curve_size.high, 0xffffffff00000000ffffffffffffffff);
}

#[test]
fn test_get_point_from_x_syscall_on_curve_size_is_none() {
    let curve_size = Secp256r1Impl::get_curve_size();
    match Secp256r1Impl::secp256_ec_get_point_from_x_syscall(curve_size, true).unwrap_syscall() {
        Option::Some(_data) => { assert_eq!(true, false); },
        Option::None => { assert_eq!(true, true); },
    }

    match Secp256r1Impl::secp256_ec_get_point_from_x_syscall(curve_size, false).unwrap_syscall() {
        Option::Some(_data) => { assert_eq!(true, false); },
        Option::None => { assert_eq!(true, true); },
    }
}

#[test]
fn test_pack_big_secp256r1_points() {
    let (big_point_1, big_point_2) = get_points();
    let private_key = P256_PRIVATEKEY_SAMPLE();

    // Check point 1

    let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_1);
    let xhigh_and_parity: u256 = xhigh_and_parity.into();

    let x = u256 {
        low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap()
    };
    let parity = xhigh_and_parity % 2 == 1;

    assert_eq!(x, private_key);
    assert_eq!(parity, true, "Parity should be odd");

    // Check point 2

    let (xlow, xhigh_and_parity) = StorePacking::pack(big_point_2);
    let xhigh_and_parity: u256 = xhigh_and_parity.into();

    let x = u256 {
        low: xlow.try_into().unwrap(), high: (xhigh_and_parity / 2).try_into().unwrap()
    };
    let parity = xhigh_and_parity % 2 == 1;

    assert_eq!(x, private_key);
    assert_eq!(parity, false, "Parity should be even");
}

#[test]
fn test_unpack_big_secp256r1_points() {
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
    assert_eq!(y, expected_y);
}

#[test]
fn test_secp256r1_serialization() {
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
fn test_secp256r1_deserialization() {
    let (big_point_1, big_point_2) = get_points();

    // Check point 1

    let mut expected_serialization = array![];

    big_point_1.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);
    let mut expected_serialization = expected_serialization.span();
    let deserialized_point = Secp256r1PointSerde::deserialize(ref expected_serialization).unwrap();

    assert_eq!(big_point_1, deserialized_point);

    // Check point 2

    let mut expected_serialization = array![];

    big_point_2.get_coordinates().unwrap_syscall().serialize(ref expected_serialization);
    let mut expected_serialization = expected_serialization.span();
    let deserialized_point = Secp256r1PointSerde::deserialize(ref expected_serialization).unwrap();

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

/// This signature was computed using @noble/curves.
fn P256_PRIVATEKEY_SAMPLE() -> u256 {
    0x1efecf7ee1e25bb87098baf2aaab0406167aae0d5ea9ba0d31404bf01886bd0e
}

fn get_points() -> (Secp256r1Point, Secp256r1Point) {
    let private_key = P256_PRIVATEKEY_SAMPLE();
    let point_1 = Secp256r1Impl::secp256_ec_get_point_from_x_syscall(private_key, true)
        .unwrap_syscall()
        .unwrap();
    let point_2 = Secp256r1Impl::secp256_ec_get_point_from_x_syscall(private_key, false)
        .unwrap_syscall()
        .unwrap();

    (point_1, point_2)
}
