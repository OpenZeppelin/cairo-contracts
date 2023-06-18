use traits::Into;
use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use zeroable::Zeroable;

// Dispatchers
use openzeppelin::access::accesscontrol::interface::IAccessControlDispatcher;
use openzeppelin::access::accesscontrol::interface::IAccessControlCamelDispatcher;
use openzeppelin::access::accesscontrol::interface::IAccessControlDispatcherTrait;
use openzeppelin::access::accesscontrol::interface::IAccessControlCamelDispatcherTrait;

// Dual case AccessControl
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControlTrait;
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControl;

// Mocks
use openzeppelin::tests::mocks::snake_accesscontrol_mock::SnakeAccessControlMock;
use openzeppelin::tests::mocks::camel_accesscontrol_mock::CamelAccessControlMock;
use openzeppelin::tests::mocks::accesscontrol_panic_mock::SnakeAccessControlPanicMock;
use openzeppelin::tests::mocks::accesscontrol_panic_mock::CamelAccessControlPanicMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;

// Other
use openzeppelin::tests::utils;
use openzeppelin::tests::utils::PanicTrait;
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

///
/// Constants
///

fn ADMIN() -> ContractAddress {
    contract_address_const::<10>()
}

fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<20>()
}

const ROLE: felt252 = 41;

///
/// Setup
///

fn setup_snake() -> (DualCaseAccessControl, IAccessControlDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(ADMIN().into());
    //set_caller_address(OWNER());
    let target = utils::deploy(SnakeAccessControlMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccessControl {
            contract_address: target
            }, IAccessControlDispatcher {
            contract_address: target
        }
    )
}

fn setup_camel() -> (DualCaseAccessControl, IAccessControlDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(ADMIN().into());
    //set_caller_address(OWNER());
    let target = utils::deploy(CamelAccessControlMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccessControl {
            contract_address: target
            }, IAccessControlDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_accesscontrol() -> DualCaseAccessControl {
    let calldata = ArrayTrait::new();
    //set_caller_address(OWNER());
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseAccessControl { contract_address: target }
}

fn setup_accesscontrol_panic() -> (DualCaseAccessControl, DualCaseAccessControl) {
    //set_caller_address(OWNER());
    let snake_target = utils::deploy(
        SnakeAccessControlPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    let camel_target = utils::deploy(
        CamelAccessControlPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    (
        DualCaseAccessControl {
            contract_address: snake_target
            }, DualCaseAccessControl {
            contract_address: camel_target
        }
    )
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_has_role() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN()), 'Should have role');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_has_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_has_role_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[available_gas(2000000)]
fn test_dual_get_role_admin() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE, '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_get_role_admin() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.get_role_admin(ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_get_role_admin_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.get_role_admin(ROLE);
}

#[test]
#[available_gas(2000000)]
fn test_dual_grant_role() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.grant_role(ROLE, AUTHORIZED());
    assert(target.has_role(ROLE, AUTHORIZED()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_grant_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_grant_role_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_dual_revoke_role() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.revoke_role(ROLE, AUTHORIZED());
    assert(!target.has_role(ROLE, AUTHORIZED()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_revoke_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_revoke_role_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_dual_renounce_role() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert(!target.has_role(DEFAULT_ADMIN_ROLE, ADMIN()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_renounce_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_renounce_role_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_hasRole() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN()), 'Should have role');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_hasRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[available_gas(2000000)]
fn test_dual_getRoleAdmin() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE, '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_getRoleAdmin_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.get_role_admin(ROLE);
}

#[ignore] //Bug with test-runner
#[test]
#[available_gas(2000000)]
fn test_dual_grantRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.grant_role(ROLE, AUTHORIZED());
    assert(target.has_role(ROLE, AUTHORIZED()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_grantRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[ignore] //Bug with test-runner
#[test]
#[available_gas(2000000)]
fn test_dual_revokeRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.grant_role(ROLE, AUTHORIZED());
    dispatcher.revoke_role(ROLE, AUTHORIZED());
    assert(!target.has_role(ROLE, AUTHORIZED()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_revokeRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[ignore] //Bug with test-runner
#[test]
#[available_gas(2000000)]
fn test_dual_renounceRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN()); //Bug with test-runner
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert(!target.has_role(DEFAULT_ADMIN_ROLE, ADMIN()), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_renounceRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

