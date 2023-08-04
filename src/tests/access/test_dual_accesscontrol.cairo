use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;

use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::interface::IACCESSCONTROL_ID;
use openzeppelin::access::accesscontrol::interface::IAccessControlDispatcher;
use openzeppelin::access::accesscontrol::interface::IAccessControlCamelDispatcher;
use openzeppelin::access::accesscontrol::interface::IAccessControlDispatcherTrait;
use openzeppelin::access::accesscontrol::interface::IAccessControlCamelDispatcherTrait;
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControlTrait;
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControl;
use openzeppelin::tests::mocks::snake_accesscontrol_mock::SnakeAccessControlMock;
use openzeppelin::tests::mocks::camel_accesscontrol_mock::CamelAccessControlMock;
use openzeppelin::tests::mocks::accesscontrol_panic_mock::SnakeAccessControlPanicMock;
use openzeppelin::tests::mocks::accesscontrol_panic_mock::CamelAccessControlPanicMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;

//
// Constants
//

const ROLE: felt252 = 41;

fn ADMIN() -> ContractAddress {
    contract_address_const::<10>()
}

fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<20>()
}

//
// Setup
//

fn setup_snake() -> (DualCaseAccessControl, IAccessControlDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ADMIN());
    let target = utils::deploy(SnakeAccessControlMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccessControl {
            contract_address: target
            }, IAccessControlDispatcher {
            contract_address: target
        }
    )
}

fn setup_camel() -> (DualCaseAccessControl, IAccessControlCamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ADMIN());
    let target = utils::deploy(CamelAccessControlMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccessControl {
            contract_address: target
            }, IAccessControlCamelDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_accesscontrol() -> DualCaseAccessControl {
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    DualCaseAccessControl { contract_address: target }
}

fn setup_accesscontrol_panic() -> (DualCaseAccessControl, DualCaseAccessControl) {
    let snake_target = utils::deploy(SnakeAccessControlPanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelAccessControlPanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseAccessControl {
            contract_address: snake_target
            }, DualCaseAccessControl {
            contract_address: camel_target
        }
    )
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.supports_interface(IACCESSCONTROL_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.supports_interface(IACCESSCONTROL_ID);
}

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
    assert(dispatcher.get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE, 'Should get admin');
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
    set_contract_address(ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());
    assert(target.has_role(ROLE, AUTHORIZED()), 'Should grant role');
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
    set_contract_address(ADMIN());
    dispatcher.revoke_role(ROLE, AUTHORIZED());
    assert(!target.has_role(ROLE, AUTHORIZED()), 'Should revoke role');
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
    set_contract_address(ADMIN());
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert(!target.has_role(DEFAULT_ADMIN_ROLE, ADMIN()), 'Should renounce role');
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

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_supportsInterface() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.supports_interface(IACCESSCONTROL_ID);
}

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
    assert(dispatcher.get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE, 'Should get admin');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_getRoleAdmin_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.get_role_admin(ROLE);
}

#[test]
#[available_gas(2000000)]
fn test_dual_grantRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());
    assert(target.hasRole(ROLE, AUTHORIZED()), 'Should grant role');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_grantRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_dual_revokeRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());
    dispatcher.revoke_role(ROLE, AUTHORIZED());
    assert(!target.hasRole(ROLE, AUTHORIZED()), 'Should revoke role');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_revokeRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_dual_renounceRole() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(ADMIN());
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert(!target.hasRole(DEFAULT_ADMIN_ROLE, ADMIN()), 'Should renounce role');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_renounceRole_exists_and_panics() {
    let (_, dispatcher) = setup_accesscontrol_panic();
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

