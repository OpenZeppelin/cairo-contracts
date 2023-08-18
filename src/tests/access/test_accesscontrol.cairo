use openzeppelin::access::accesscontrol::AccessControl::AccessControlCamelImpl;
use openzeppelin::access::accesscontrol::AccessControl::AccessControlImpl;
use openzeppelin::access::accesscontrol::AccessControl::InternalImpl;
use openzeppelin::access::accesscontrol::AccessControl::RoleAdminChanged;
use openzeppelin::access::accesscontrol::AccessControl::RoleGranted;
use openzeppelin::access::accesscontrol::AccessControl::RoleRevoked;
use openzeppelin::access::accesscontrol::AccessControl;
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::interface::IACCESSCONTROL_ID;
use openzeppelin::tests::utils::constants::{
    ADMIN, AUTHORIZED, OTHER, OTHER_ADMIN, ROLE, OTHER_ROLE, ZERO
};
use openzeppelin::tests::utils;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;

//
// Setup
//

fn STATE() -> AccessControl::ContractState {
    AccessControl::contract_state_for_testing()
}

fn setup() -> AccessControl::ContractState {
    let mut state = STATE();
    InternalImpl::_grant_role(ref state, DEFAULT_ADMIN_ROLE, ADMIN());
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
    InternalImpl::initializer(ref state);
    assert(
        AccessControl::SRC5Impl::supports_interface(@state, IACCESSCONTROL_ID),
        'Should support own interface'
    );
}
//
// supports_interface & supportsInterface
//

#[test]
#[available_gas(2000000)]
fn test_supports_interface() {
    let mut state = STATE();
    InternalImpl::initializer(ref state);
    assert(
        AccessControl::SRC5Impl::supports_interface(@state, IACCESSCONTROL_ID),
        'Should support own interface'
    );
}

#[test]
#[available_gas(2000000)]
fn test_supportsInterface() {
    let mut state = STATE();
    InternalImpl::initializer(ref state);
    assert(
        AccessControl::SRC5CamelImpl::supportsInterface(@state, IACCESSCONTROL_ID),
        'Should support own interface'
    );
}

//
// has_role & hasRole
//

#[test]
#[available_gas(2000000)]
fn test_has_role() {
    let mut state = setup();
    assert(!AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'should not have role');
    InternalImpl::_grant_role(ref state, ROLE, AUTHORIZED());
    assert(AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'should have role');
}

#[test]
#[available_gas(2000000)]
fn test_hasRole() {
    let mut state = setup();
    assert(!AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'should not have role');
    InternalImpl::_grant_role(ref state, ROLE, AUTHORIZED());
    assert(AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'should have role');
}


//
// assert_only_role
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    InternalImpl::assert_only_role(@state, ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_assert_only_role_unauthorized() {
    let state = setup();
    testing::set_caller_address(OTHER());
    InternalImpl::assert_only_role(@state, ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_assert_only_role_unauthorized_when_authorized_for_another_role() {
    let mut state = setup();
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    InternalImpl::assert_only_role(@state, OTHER_ROLE);
}

//
// grant_role & grantRole
//

#[test]
#[available_gas(2000000)]
fn test_grant_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());

    assert_event_role_granted(ROLE, AUTHORIZED(), ADMIN());
    assert(AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grantRole() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());

    assert_event_role_granted(ROLE, AUTHORIZED(), ADMIN());
    assert(AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grant_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    assert(AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should still be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grantRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
    assert(
        AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'Role should still be granted'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_grant_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_grantRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
}

//
// revoke_role & revokeRole
//

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlCamelImpl::revokeRole(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), ADMIN());
    assert(!AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    AccessControlCamelImpl::revokeRole(ref state, ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), ADMIN());
    assert(!AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
    assert(
        !AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should still be revoked'
    );
}

#[test]
#[available_gas(2000000)]
fn test_revokeRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
    AccessControlCamelImpl::revokeRole(ref state, ROLE, AUTHORIZED());
    AccessControlCamelImpl::revokeRole(ref state, ROLE, AUTHORIZED());
    assert(
        !AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'Role should still be revoked'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_revoke_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_revokeRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    AccessControlCamelImpl::revokeRole(ref state, ROLE, AUTHORIZED());
}

//
// renounce_role & renounceRole
//

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    AccessControlImpl::renounce_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_for_role_not_granted() {
    let mut state = setup();
    testing::set_caller_address(AUTHORIZED());
    AccessControlCamelImpl::renounceRole(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    testing::set_caller_address(AUTHORIZED());
    AccessControlImpl::renounce_role(ref state, ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), AUTHORIZED());
    assert(!AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());

    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());
    utils::drop_event(ZERO());

    testing::set_caller_address(AUTHORIZED());
    AccessControlCamelImpl::renounceRole(ref state, ROLE, AUTHORIZED());

    assert_event_role_revoked(ROLE, AUTHORIZED(), AUTHORIZED());
    assert(
        !AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()), 'Role should be renounced'
    );
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    AccessControlImpl::renounce_role(ref state, ROLE, AUTHORIZED());
    AccessControlImpl::renounce_role(ref state, ROLE, AUTHORIZED());
    assert(
        !AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'Role should still be renounced'
    );
}

#[test]
#[available_gas(2000000)]
fn test_renounceRole_multiple_times_for_granted_role() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());

    testing::set_caller_address(AUTHORIZED());
    AccessControlCamelImpl::renounceRole(ref state, ROLE, AUTHORIZED());
    AccessControlCamelImpl::renounceRole(ref state, ROLE, AUTHORIZED());
    assert(
        !AccessControlCamelImpl::hasRole(@state, ROLE, AUTHORIZED()),
        'Role should still be renounced'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self', ))]
fn test_renounce_role_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());

    testing::set_caller_address(ZERO());
    AccessControlImpl::renounce_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self', ))]
fn test_renounceRole_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(ADMIN());
    AccessControlCamelImpl::grantRole(ref state, ROLE, AUTHORIZED());

    // Admin is unauthorized caller
    AccessControlCamelImpl::renounceRole(ref state, ROLE, AUTHORIZED());
}

//
// _set_role_admin
//

#[test]
#[available_gas(2000000)]
fn test__set_role_admin() {
    let mut state = setup();
    assert(
        AccessControlImpl::get_role_admin(@state, ROLE) == DEFAULT_ADMIN_ROLE,
        'ROLE admin default should be 0'
    );
    InternalImpl::_set_role_admin(ref state, ROLE, OTHER_ROLE);

    assert_event_role_admin_changed(ROLE, DEFAULT_ADMIN_ROLE, OTHER_ROLE);
    assert(
        AccessControlImpl::get_role_admin(@state, ROLE) == OTHER_ROLE,
        'ROLE admin should be OTHER_ROLE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_grant_roles() {
    let mut state = setup();
    InternalImpl::_set_role_admin(ref state, ROLE, OTHER_ROLE);

    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    assert(AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'AUTHORIZED should have ROLE');
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_revoke_roles() {
    let mut state = setup();
    InternalImpl::_set_role_admin(ref state, ROLE, OTHER_ROLE);

    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
    assert(
        !AccessControlImpl::has_role(@state, ROLE, AUTHORIZED()), 'AUTHORIZED should not have ROLE'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_previous_admin_cannot_grant_roles() {
    let mut state = setup();
    InternalImpl::_set_role_admin(ref state, ROLE, OTHER_ROLE);
    testing::set_caller_address(ADMIN());
    AccessControlImpl::grant_role(ref state, ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_previous_admin_cannot_revoke_roles() {
    let mut state = setup();
    InternalImpl::_set_role_admin(ref state, ROLE, OTHER_ROLE);
    testing::set_caller_address(ADMIN());
    AccessControlImpl::revoke_role(ref state, ROLE, AUTHORIZED());
}

//
// Default admin
//

#[test]
#[available_gas(2000000)]
fn test_other_role_admin_is_the_default_admin_role() {
    let state = setup();
    assert(
        AccessControlImpl::get_role_admin(@state, OTHER_ROLE) == DEFAULT_ADMIN_ROLE,
        'Should be DEFAULT_ADMIN_ROLE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_default_admin_role_is_its_own_admin() {
    let state = setup();
    assert(
        AccessControlImpl::get_role_admin(@state, DEFAULT_ADMIN_ROLE) == DEFAULT_ADMIN_ROLE,
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
