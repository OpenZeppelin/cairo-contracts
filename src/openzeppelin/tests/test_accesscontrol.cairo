use openzeppelin::tests::mocks::mock_accesscontrol::MockAccessControl;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::set_caller_address;

const DEFAULT_ADMIN_ROLE: felt252 = 0;
const SOME_OTHER_ROLE: felt252 = 42;

fn ACCOUNT1() -> ContractAddress {
    contract_address_const::<1>()
}

fn ACCOUNT2() -> ContractAddress {
    contract_address_const::<2>()
}

fn setup() {
    set_caller_address(ACCOUNT1());
    MockAccessControl::constructor(ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    MockAccessControl::constructor(ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_grant_role() {
    setup();
    MockAccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
    assert(MockAccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT2()), 'Role should be granted');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Caller is missing role', ))]
fn test_grant_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    MockAccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());
}

#[test]
#[available_gas(2000000)]
fn test_revoke_role() {
    setup();
    MockAccessControl::grant_role(DEFAULT_ADMIN_ROLE, ACCOUNT2());

    set_caller_address(ACCOUNT2());
    MockAccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(!MockAccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'Role should be revoked');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Caller is missing role', ))]
fn test_revoke_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    MockAccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_renounce_role() {
    setup();
    MockAccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
    assert(!MockAccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'Role should be renounced');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Can only renounce role for self', ))]
fn test_renounce_role_unauthorized() {
    setup();
    set_caller_address(ACCOUNT2());
    MockAccessControl::renounce_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());
}

#[test]
#[available_gas(2000000)]
fn test_set_role_admin() {
    setup();
    MockAccessControl::set_role_admin(DEFAULT_ADMIN_ROLE, SOME_OTHER_ROLE);
    assert(MockAccessControl::get_role_admin(DEFAULT_ADMIN_ROLE) == SOME_OTHER_ROLE, 'Should set the admin role');

    // Test role admin cycle
    MockAccessControl::grant_role(SOME_OTHER_ROLE, ACCOUNT2());
    assert(MockAccessControl::has_role(SOME_OTHER_ROLE, ACCOUNT2()), 'ACCOUNT2 should have role');

    set_caller_address(ACCOUNT2());
    MockAccessControl::revoke_role(DEFAULT_ADMIN_ROLE, ACCOUNT1());

    assert(!MockAccessControl::has_role(DEFAULT_ADMIN_ROLE, ACCOUNT1()), 'ACCOUNT1 should not have role');
}
