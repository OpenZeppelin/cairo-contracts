use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControl;
use openzeppelin::access::accesscontrol::dual_accesscontrol::DualCaseAccessControlTrait;
use openzeppelin::access::accesscontrol::interface::{
    IACCESSCONTROL_ID, IAccessControlDispatcher, IAccessControlDispatcherTrait,
    IAccessControlCamelDispatcher, IAccessControlCamelDispatcherTrait
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{ADMIN, AUTHORIZED, ROLE};
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address, test_address};
use starknet::ContractAddress;

//
// Setup
//

fn setup_snake() -> (DualCaseAccessControl, IAccessControlDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ADMIN());
    let target = utils::declare_and_deploy("SnakeAccessControlMock", calldata);
    (
        DualCaseAccessControl { contract_address: target },
        IAccessControlDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseAccessControl, IAccessControlCamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ADMIN());
    let target = utils::declare_and_deploy("CamelAccessControlMock", calldata);
    (
        DualCaseAccessControl { contract_address: target },
        IAccessControlCamelDispatcher { contract_address: target }
    )
}

fn setup_non_accesscontrol() -> DualCaseAccessControl {
    let target = utils::declare_and_deploy("NonImplementingMock", array![]);
    DualCaseAccessControl { contract_address: target }
}

fn setup_accesscontrol_panic() -> (DualCaseAccessControl, DualCaseAccessControl) {
    let snake_target = utils::declare_and_deploy("SnakeAccessControlPanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelAccessControlPanicMock", array![]);
    (
        DualCaseAccessControl { contract_address: snake_target },
        DualCaseAccessControl { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_snake();
    let supports_iaccesscontrol = dispatcher.supports_interface(IACCESSCONTROL_ID);
    assert!(supports_iaccesscontrol);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.supports_interface(IACCESSCONTROL_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_supports_interface_exists_and_panics() {
    let (snake_dispatcher, _) = setup_accesscontrol_panic();
    snake_dispatcher.supports_interface(IACCESSCONTROL_ID);
}

#[test]
fn test_dual_has_role() {
    let (snake_dispatcher, _) = setup_snake();
    let has_role = snake_dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert!(has_role);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_has_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_has_role_exists_and_panics() {
    let (dispatcher, _) = setup_accesscontrol_panic();
    dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
fn test_dual_get_role_admin() {
    let (dispatcher, _) = setup_snake();
    let current_admin_role = dispatcher.get_role_admin(ROLE);
    assert_eq!(current_admin_role, DEFAULT_ADMIN_ROLE);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_role_admin() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.get_role_admin(ROLE);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_get_role_admin_exists_and_panics() {
    let (snake_dispatcher, _) = setup_accesscontrol_panic();
    snake_dispatcher.get_role_admin(ROLE);
}

#[test]
fn test_dual_grant_role() {
    let (dispatcher, target) = setup_snake();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());

    let has_role = target.has_role(ROLE, AUTHORIZED());
    assert!(has_role);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_grant_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_grant_role_exists_and_panics() {
    let (snake_dispatcher, _) = setup_accesscontrol_panic();
    snake_dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
fn test_dual_revoke_role() {
    let (dispatcher, target) = setup_snake();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.revoke_role(ROLE, AUTHORIZED());

    let has_not_role = !target.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_revoke_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_revoke_role_exists_and_panics() {
    let (snake_dispatcher, _) = setup_accesscontrol_panic();
    snake_dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
fn test_dual_renounce_role() {
    let (dispatcher, target) = setup_snake();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());

    let has_not_role = !target.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert!(has_not_role);
}

#[test]
#[ignore] // TODO: Enable when ENTRYPOINT_NOT_FOUND issue is solved
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_renounce_role() {
    let dispatcher = setup_non_accesscontrol();
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_renounce_role_exists_and_panics() {
    let (snake_dispatcher, _) = setup_accesscontrol_panic();
    snake_dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

//
// camelCase target
//

#[test]
#[ignore] // TODO: Enable when try/catch is supported
fn test_dual_hasRole() {
    let (dispatcher, _) = setup_camel();

    let has_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
    assert!(has_role);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
#[should_panic(expected: ("Some error",))]
fn test_dual_hasRole_exists_and_panics() {
    let (_, camel_dispatcher) = setup_accesscontrol_panic();
    camel_dispatcher.has_role(DEFAULT_ADMIN_ROLE, ADMIN());
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
fn test_dual_getRoleAdmin() {
    let (dispatcher, _) = setup_camel();

    let current_admin_role = dispatcher.get_role_admin(ROLE);
    assert_eq!(current_admin_role, DEFAULT_ADMIN_ROLE);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
#[should_panic(expected: ("Some error",))]
fn test_dual_getRoleAdmin_exists_and_panics() {
    let (_, camel_dispatcher) = setup_accesscontrol_panic();
    camel_dispatcher.get_role_admin(ROLE);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
fn test_dual_grantRole() {
    let (dispatcher, target) = setup_camel();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());

    let has_role = target.hasRole(ROLE, AUTHORIZED());
    assert!(has_role);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
#[should_panic(expected: ("Some error",))]
fn test_dual_grantRole_exists_and_panics() {
    let (_, camel_dispatcher) = setup_accesscontrol_panic();
    camel_dispatcher.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
fn test_dual_revokeRole() {
    let (dispatcher, target) = setup_camel();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.grant_role(ROLE, AUTHORIZED());
    dispatcher.revoke_role(ROLE, AUTHORIZED());

    let has_not_role = !target.hasRole(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
#[should_panic(expected: ("Some error",))]
fn test_dual_revokeRole_exists_and_panics() {
    let (_, camel_dispatcher) = setup_accesscontrol_panic();
    camel_dispatcher.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
fn test_dual_renounceRole() {
    let (dispatcher, target) = setup_camel();
    start_cheat_caller_address(target.contract_address, ADMIN());
    dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());

    let has_not_role = !target.hasRole(DEFAULT_ADMIN_ROLE, ADMIN());
    assert!(has_not_role);
}

#[test]
#[ignore] // TODO: Enable when try/catch is supported
#[should_panic(expected: ("Some error",))]
fn test_dual_renounceRole_exists_and_panics() {
    let (_, camel_dispatcher) = setup_accesscontrol_panic();
    camel_dispatcher.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN());
}
