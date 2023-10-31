use openzeppelin::access::accesscontrol::AccessControlComponent::InternalImpl;
use openzeppelin::access::accesscontrol::AccessControlComponent::RoleAdminChanged;
use openzeppelin::access::accesscontrol::AccessControlComponent::RoleGranted;
use openzeppelin::access::accesscontrol::AccessControlComponent::RoleRevoked;
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::interface::IACCESSCONTROL_ID;
use openzeppelin::access::accesscontrol::interface::{IAccessControl, IAccessControlCamel};
use openzeppelin::introspection::interface::{ISRC5, ISRC5Camel};
use openzeppelin::tests::mocks::accesscontrol_mocks::DualCaseAccessControlMock;
use openzeppelin::tests::utils::constants::{
    ADMIN, AUTHORIZED, OTHER, OTHER_ADMIN, ROLE, OTHER_ROLE, ZERO
};
use openzeppelin::tests::utils;
use starknet::ContractAddress;
use starknet::testing;

//
// Setup
//

fn STATE() -> DualCaseAccessControlMock::ContractState {
    DualCaseAccessControlMock::contract_state_for_testing()
}

fn setup() -> DualCaseAccessControlMock::ContractState {
    let mut state = STATE();
    state.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, ADMIN());
    utils::drop_event(ZERO());
    state
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    state.accesscontrol.initializer();
    assert(state.src5.supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}
//
// supports_interface & supportsInterface
//

#[test]
#[available_gas(2000000)]
fn test_supports_interface() {
    let mut state = STATE();
    state.accesscontrol.initializer();
    assert(state.src5.supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}

#[test]
#[available_gas(2000000)]
fn test_supportsInterface() {
    let mut state = STATE();
    state.accesscontrol.initializer();
    assert(state.src5.supportsInterface(IACCESSCONTROL_ID), 'Should support own interface');
}

//
// has_role & hasRole
//

#[test]
#[available_gas(2000000)]
fn test_has_role() {
    let mut state = setup();
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'should not have role');
    state.accesscontrol._grant_role(ROLE, AUTHORIZED());
    assert(state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'should have role');
}

#[test]
#[available_gas(2000000)]
fn test_hasRole() {
    let mut state = setup();
    assert(!state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'should not have role');
    state.accesscontrol._grant_role(ROLE, AUTHORIZED());
    assert(state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'should have role');
}


//
// assert_only_role
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.assert_only_role(ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_assert_only_role_unauthorized() {
    let state = setup();
    testing::set_caller_address(OTHER());
    state.accesscontrol.assert_only_role(ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_assert_only_role_unauthorized_when_authorized_for_another_role() {
    let mut state = setup();
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.assert_only_role(OTHER_ROLE);
}

//
// grant_role & grantRole
//

#[test]
#[available_gas(2000000)]
fn test_grant_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());

    assert_event_role_granted(ROLE, AUTHORIZED(), ADMIN());
    assert(state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grantRole() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grantRole(ROLE, AUTHORIZED());

    assert_event_role_granted(ROLE, AUTHORIZED(), ADMIN());
    assert(state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grant_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    assert(state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should still be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grantRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
    assert(state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should still be granted');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_grant_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_grantRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
}

//
// revoke_role & revokeRole
//

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.revokeRole(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), ADMIN());
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    state.accesscontrol.revokeRole(ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), ADMIN());
    assert(!state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should still be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
    state.accesscontrol.revokeRole(ROLE, AUTHORIZED());
    state.accesscontrol.revokeRole(ROLE, AUTHORIZED());
    assert(!state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should still be revoked');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_revoke_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_revokeRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.accesscontrol.revokeRole(ROLE, AUTHORIZED());
}

//
// renounce_role & renounceRole
//

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounce_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounceRole(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounce_role(ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), AUTHORIZED());
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    state.accesscontrol.grantRole(ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounceRole(ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), AUTHORIZED());
    assert(!state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounce_role(ROLE, AUTHORIZED());
    state.accesscontrol.renounce_role(ROLE, AUTHORIZED());
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'Role should still be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grantRole(ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    state.accesscontrol.renounceRole(ROLE, AUTHORIZED());
    state.accesscontrol.renounceRole(ROLE, AUTHORIZED());
    assert(!state.accesscontrol.hasRole(ROLE, AUTHORIZED()), 'Role should still be renounced');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self',))]
fn test_renounce_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());

    testing::set_caller_address(ZERO());
    state.accesscontrol.renounce_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self',))]
fn test_renounceRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grantRole(ROLE, AUTHORIZED());

    // Admin is unauthorized caller
    state.accesscontrol.renounceRole(ROLE, AUTHORIZED());
}

//
// _set_role_admin
//

#[test]
#[available_gas(2000000)]
fn test__set_role_admin() {
    let mut state = setup();
    assert(
        state.accesscontrol.get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE,
        'ROLE admin default should be 0'
    );
    state.accesscontrol._set_role_admin(ROLE, OTHER_ROLE);

    assert_event_role_admin_changed(ROLE, DEFAULT_ADMIN_ROLE, OTHER_ROLE);
    assert(
        state.accesscontrol.get_role_admin(ROLE) == OTHER_ROLE, 'ROLE admin should be OTHER_ROLE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_grant_roles() {
    let mut state = setup();
    state.accesscontrol._set_role_admin(ROLE, OTHER_ROLE);

    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    assert(state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'AUTHORIZED should have ROLE');
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_revoke_roles() {
    let mut state = setup();
    state.accesscontrol._set_role_admin(ROLE, OTHER_ROLE);

    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
    assert(!state.accesscontrol.has_role(ROLE, AUTHORIZED()), 'AUTHORIZED should not have ROLE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_previous_admin_cannot_grant_roles() {
    let mut state = setup();
    state.accesscontrol._set_role_admin(ROLE, OTHER_ROLE);
    testing::set_caller_address(ADMIN());
    state.accesscontrol.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role',))]
fn test_previous_admin_cannot_revoke_roles() {
    let mut state = setup();
    state.accesscontrol._set_role_admin(ROLE, OTHER_ROLE);
    testing::set_caller_address(ADMIN());
    state.accesscontrol.revoke_role(ROLE, AUTHORIZED());
}

//
// Default admin
//

#[test]
#[available_gas(2000000)]
fn test_other_role_admin_is_the_default_admin_role() {
    let state = setup();
    assert(
        state.accesscontrol.get_role_admin(OTHER_ROLE) == DEFAULT_ADMIN_ROLE,
        'Should be DEFAULT_ADMIN_ROLE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_default_admin_role_is_its_own_admin() {
    let state = setup();
    assert(
        state.accesscontrol.get_role_admin(DEFAULT_ADMIN_ROLE) == DEFAULT_ADMIN_ROLE,
        'Should be DEFAULT_ADMIN_ROLE'
    );
}

//
// Helpers
//

fn assert_event_role_revoked(role: felt252, account: ContractAddress, sender: ContractAddress) {
    let event = utils::pop_log::<RoleRevoked>(ZERO()).unwrap();
    assert(event.role == role, 'Invalid `role`');
    assert(event.account == account, 'Invalid `account`');
    assert(event.sender == sender, 'Invalid `sender`');
    utils::assert_no_events_left(ZERO());
}

fn assert_event_role_granted(role: felt252, account: ContractAddress, sender: ContractAddress) {
    let event = utils::pop_log::<RoleGranted>(ZERO()).unwrap();
    assert(event.role == role, 'Invalid `role`');
    assert(event.account == account, 'Invalid `account`');
    assert(event.sender == sender, 'Invalid `sender`');
    utils::assert_no_events_left(ZERO());
}

fn assert_event_role_admin_changed(
    role: felt252, previous_admin_role: felt252, new_admin_role: felt252
) {
    let event = utils::pop_log::<RoleAdminChanged>(ZERO()).unwrap();
    assert(event.role == role, 'Invalid `role`');
    assert(event.previous_admin_role == previous_admin_role, 'Invalid `previous_admin_role`');
    assert(event.new_admin_role == new_admin_role, 'Invalid `new_admin_role`');
    utils::assert_no_events_left(ZERO());
}
