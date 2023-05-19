use openzeppelin::access::accesscontrol::AccessControl;
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::IACCESSCONTROL_ID;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing;

const ROLE: felt252 = 41;
const OTHER_ROLE: felt252 = 42;

fn ADMIN() -> ContractAddress {
    contract_address_const::<1>()
}

fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<2>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<3>()
}

fn OTHER_ADMIN() -> ContractAddress {
    contract_address_const::<4>()
}

fn setup() {
    AccessControl::_grant_role(DEFAULT_ADMIN_ROLE, ADMIN());
    testing::set_caller_address(ADMIN());
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    AccessControl::initializer();
    assert(AccessControl::supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}

//
// has_role
//

#[test]
#[available_gas(2000000)]
fn test_has_role() {
    setup();
    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'should not have role');
    AccessControl::_grant_role(ROLE, AUTHORIZED());
    assert(AccessControl::has_role(ROLE, AUTHORIZED()), 'should have role');
}


//
// assert_only_role
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    testing::set_caller_address(AUTHORIZED());
    AccessControl::assert_only_role(ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_assert_only_role_unauthorized() {
    setup();
    testing::set_caller_address(OTHER());
    AccessControl::assert_only_role(ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_assert_only_role_unauthorized_when_authorized_for_another_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    testing::set_caller_address(AUTHORIZED());
    AccessControl::assert_only_role(OTHER_ROLE);
}

//
// grant_role
//

#[test]
#[available_gas(2000000)]
fn test_grant_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    assert(AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grant_role_multiple_times_for_granted_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    AccessControl::grant_role(ROLE, AUTHORIZED());
    assert(AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should still be granted');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_grant_role_unauthorized() {
    setup();
    testing::set_caller_address(AUTHORIZED());
    AccessControl::grant_role(ROLE, AUTHORIZED());
}

//
// revoke_role
//

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_role_not_granted() {
    setup();
    AccessControl::revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_for_granted_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    AccessControl::revoke_role(ROLE, AUTHORIZED());
    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_multiple_times_for_granted_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());

    AccessControl::revoke_role(ROLE, AUTHORIZED());
    AccessControl::revoke_role(ROLE, AUTHORIZED());
    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should still be revoked');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_revoke_role_unauthorized() {
    setup();

    testing::set_caller_address(OTHER());
    AccessControl::revoke_role(ROLE, AUTHORIZED());
}

//
// renounce_role
//

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_role_not_granted() {
    setup();
    testing::set_caller_address(AUTHORIZED());

    AccessControl::renounce_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_for_granted_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    testing::set_caller_address(AUTHORIZED());

    AccessControl::renounce_role(ROLE, AUTHORIZED());
    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_multiple_times_for_granted_role() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());
    testing::set_caller_address(AUTHORIZED());

    AccessControl::renounce_role(ROLE, AUTHORIZED());
    AccessControl::renounce_role(ROLE, AUTHORIZED());
    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'Role should still be renounced');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self', ))]
fn test_renounce_role_unauthorized() {
    setup();
    AccessControl::grant_role(ROLE, AUTHORIZED());

    // Admin is unauthorized caller
    AccessControl::renounce_role(ROLE, AUTHORIZED());
}

//
// _set_role_admin
//

#[test]
#[available_gas(2000000)]
fn test__set_role_admin() {
    setup();
    assert(
        AccessControl::get_role_admin(ROLE) == DEFAULT_ADMIN_ROLE, 'ROLE admin default should be 0'
    );
    AccessControl::_set_role_admin(ROLE, OTHER_ROLE);
    assert(AccessControl::get_role_admin(ROLE) == OTHER_ROLE, 'ROLE admin should be OTHER_ROLE');
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_grant_roles() {
    setup();
    AccessControl::_set_role_admin(ROLE, OTHER_ROLE);
    AccessControl::grant_role(OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    AccessControl::grant_role(ROLE, AUTHORIZED());

    assert(AccessControl::has_role(ROLE, AUTHORIZED()), 'AUTHORIZED should have ROLE');
}

#[test]
#[available_gas(2000000)]
fn test_new_admin_can_revoke_roles() {
    setup();
    AccessControl::_set_role_admin(ROLE, OTHER_ROLE);
    AccessControl::grant_role(OTHER_ROLE, OTHER_ADMIN());

    testing::set_caller_address(OTHER_ADMIN());
    AccessControl::grant_role(ROLE, AUTHORIZED());
    AccessControl::revoke_role(ROLE, AUTHORIZED());

    assert(!AccessControl::has_role(ROLE, AUTHORIZED()), 'AUTHORIZED should not have ROLE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_previous_admin_cannot_grant_roles() {
    setup();
    AccessControl::_set_role_admin(ROLE, OTHER_ROLE);

    // Caller is ADMIN
    AccessControl::grant_role(ROLE, AUTHORIZED());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_previous_admin_cannot_revoke_roles() {
    setup();
    AccessControl::_set_role_admin(ROLE, OTHER_ROLE);

    // Caller is ADMIN
    AccessControl::revoke_role(ROLE, AUTHORIZED());
}

//
// default admin
//

#[test]
#[available_gas(2000000)]
fn test_other_role_admin_is_the_default_admin_role() {
    assert(
        AccessControl::get_role_admin(OTHER_ROLE) == DEFAULT_ADMIN_ROLE,
        'Should be DEFAULT_ADMIN_ROLE'
    );
}

#[test]
#[available_gas(2000000)]
fn test_default_admin_role_is_its_own_admin() {
    assert(
        AccessControl::get_role_admin(DEFAULT_ADMIN_ROLE) == DEFAULT_ADMIN_ROLE,
        'Should be DEFAULT_ADMIN_ROLE'
    );
}
