use openzeppelin::access::accesscontrol::AccessControl;
use openzeppelin::utils::constants::{DEFAULT_ADMIN_ROLE, IACCESSCONTROL_ID};
use starknet::{contract_address_const, ContractAddress, testing::set_caller_address};

const SOME_OTHER_ROLE: felt252 = 42;

fn ACCOUNT1() -> ContractAddress {
    contract_address_const::<1>()
}

fn ACCOUNT2() -> ContractAddress {
    contract_address_const::<2>()
}

// Mimics a contract's constructor
fn setup() {
    set_caller_address(ACCOUNT1());
    AccessControl::_grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    AccessControl::initializer();
    assert(AccessControl::supports_interface(IACCESSCONTROL_ID), 'Should support own interface');
}

#[test]
#[available_gas(2000000)]
fn test_assert_only_role() {
    setup();
    AccessControl::assert_only_role(DEFAULT_ADMIN_ROLE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_assert_only_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    AccessControl::assert_only_role(DEFAULT_ADMIN_ROLE);
}

#[test]
#[available_gas(2000000)]
fn test_grant_role() {
    setup();
    AccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
    assert(AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT2()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
fn test_grant_role_already_granted() {
    setup();
    AccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
    AccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
    assert(AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT2()), 'Role should still be held');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_grant_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    AccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role() {
    setup();
    AccessControl::grant_role(SOME_OTHER_ROLE, ACCOUNT2());

    AccessControl::revoke_role(SOME_OTHER_ROLE, ACCOUNT2());
    assert(!AccessControl::has_role(SOME_OTHER_ROLE, ACCOUNT2()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role_already_revoked() {
    setup();
    AccessControl::grant_role(SOME_OTHER_ROLE, ACCOUNT2());

    AccessControl::revoke_role(SOME_OTHER_ROLE, ACCOUNT2());
    AccessControl::revoke_role(SOME_OTHER_ROLE, ACCOUNT2());
    assert(!AccessControl::has_role(SOME_OTHER_ROLE, ACCOUNT2()), 'Role should still be revoked');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_revoke_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    AccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role() {
    setup();
    AccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(!AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role_already_renounced() {
    setup();
    AccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    AccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(
        !AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'Role should still be renounced'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Can only renounce role for self', ))]
fn test_renounce_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    AccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_set_role_admin() {
    setup();
    AccessControl::_set_role_admin(DEFAULT_ADMIN_ROLE, SOME_OTHER_ROLE);
    assert(
        AccessControl::get_role_admin(DEFAULT_ADMIN_ROLE) == SOME_OTHER_ROLE,
        'Should set the admin role'
    );
}

#[test]
#[available_gas(2000000)]
fn test_role_admin_cycle() {
    setup();
    AccessControl::_set_role_admin(DEFAULT_ADMIN_ROLE, SOME_OTHER_ROLE);
    AccessControl::grant_role(SOME_OTHER_ROLE, ACCOUNT2());

    // Set caller to ACCOUNT2 who has SOME_OTHER_ROLE
    set_caller_address(ACCOUNT2());

    // Revoke DEFAULT_ADMIN_ROLE
    AccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(
        !AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'ACCOUNT1 should not have role'
    );

    // Grant DEFAULT_ADMIN_ROLE
    AccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(
        AccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'ACCOUNT1 should have role'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is missing role', ))]
fn test_revoked_admin_role_lost_privileges() {
    setup();
    AccessControl::_set_role_admin(DEFAULT_ADMIN_ROLE, SOME_OTHER_ROLE);
    AccessControl::grant_role(SOME_OTHER_ROLE, ACCOUNT2());
    set_caller_address(ACCOUNT2());
    AccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());

    // Set caller who has the revoked DEFAULT_ADMIN_ROLE
    set_caller_address(ACCOUNT1());
    AccessControl::revoke_role(SOME_OTHER_ROLE, ACCOUNT2());
}
