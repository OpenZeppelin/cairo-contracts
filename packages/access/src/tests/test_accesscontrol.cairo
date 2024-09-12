use crate::accesscontrol::AccessControlComponent::{
    InternalImpl, RoleAdminChanged, RoleGranted, RoleRevoked
};
use crate::accesscontrol::interface::{IAccessControl, IAccessControlCamel, IACCESSCONTROL_ID};
use crate::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
use crate::tests::mocks::accesscontrol_mocks::DualCaseAccessControlMock;
use openzeppelin_introspection::interface::ISRC5;
use openzeppelin_testing::constants::{
    ADMIN, AUTHORIZED, OTHER, OTHER_ADMIN, ROLE, OTHER_ROLE, ZERO
};
use openzeppelin_testing::events::EventSpyExt;
use snforge_std::{EventSpy, spy_events, start_cheat_caller_address, test_address};
use starknet::ContractAddress;

//
// Setup
//

type ComponentState =
    AccessControlComponent::ComponentState<DualCaseAccessControlMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseAccessControlMock::ContractState {
    DualCaseAccessControlMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    AccessControlComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state._grant_role(DEFAULT_ADMIN_ROLE, ADMIN());
    state
}

//
// initializer
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    state.initializer();
    let supports_iaccesscontrol = CONTRACT_STATE().src5.supports_interface(IACCESSCONTROL_ID);
    assert!(supports_iaccesscontrol);
}

//
// has_role & hasRole
//

#[test]
fn test_has_role() {
    let mut state = setup();
    assert!(!state.has_role(ROLE, AUTHORIZED()));
    state._grant_role(ROLE, AUTHORIZED());
    assert!(state.has_role(ROLE, AUTHORIZED()));
}

#[test]
fn test_hasRole() {
    let mut state = setup();
    assert!(!state.hasRole(ROLE, AUTHORIZED()));
    state._grant_role(ROLE, AUTHORIZED());
    assert!(state.hasRole(ROLE, AUTHORIZED()));
}

//
// assert_only_role
//

#[test]
fn test_assert_only_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(ROLE, AUTHORIZED());

    start_cheat_caller_address(contract_address, AUTHORIZED());
    state.assert_only_role(ROLE);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_assert_only_role_unauthorized() {
    let state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.assert_only_role(ROLE);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_assert_only_role_unauthorized_when_authorized_for_another_role() {
    let mut state = setup();
    state.grant_role(ROLE, AUTHORIZED());

    start_cheat_caller_address(test_address(), AUTHORIZED());
    state.assert_only_role(OTHER_ROLE);
}

//
// grant_role & grantRole
//

#[test]
fn test_grant_role() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(ROLE, AUTHORIZED());

    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED(), ADMIN());

    let has_role = state.has_role(ROLE, AUTHORIZED());
    assert!(has_role);
}

#[test]
fn test_grantRole() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grantRole(ROLE, AUTHORIZED());

    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED(), ADMIN());

    let has_role = state.hasRole(ROLE, AUTHORIZED());
    assert!(has_role);
}

#[test]
fn test_grant_role_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());

    state.grant_role(ROLE, AUTHORIZED());
    state.grant_role(ROLE, AUTHORIZED());
    assert!(state.has_role(ROLE, AUTHORIZED()));
}

#[test]
fn test_grantRole_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());

    state.grantRole(ROLE, AUTHORIZED());
    state.grantRole(ROLE, AUTHORIZED());
    assert!(state.hasRole(ROLE, AUTHORIZED()));
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_grant_role_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED());
    state.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_grantRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED());
    state.grantRole(ROLE, AUTHORIZED());
}

//
// revoke_role & revokeRole
//

#[test]
fn test_revoke_role_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());
    state.revoke_role(ROLE, AUTHORIZED());
}

#[test]
fn test_revokeRole_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());
    state.revokeRole(ROLE, AUTHORIZED());
}

#[test]
fn test_revoke_role_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());

    state.grant_role(ROLE, AUTHORIZED());

    let mut spy = spy_events();
    state.revoke_role(ROLE, AUTHORIZED());

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED(), ADMIN());

    let has_not_role = !state.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_revokeRole_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());

    state.grantRole(ROLE, AUTHORIZED());

    let mut spy = spy_events();
    state.revokeRole(ROLE, AUTHORIZED());

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED(), ADMIN());

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_revoke_role_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());

    state.grant_role(ROLE, AUTHORIZED());
    state.revoke_role(ROLE, AUTHORIZED());
    state.revoke_role(ROLE, AUTHORIZED());

    let has_not_role = !state.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_revokeRole_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());

    state.grantRole(ROLE, AUTHORIZED());
    state.revokeRole(ROLE, AUTHORIZED());
    state.revokeRole(ROLE, AUTHORIZED());

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_revoke_role_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.revoke_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_revokeRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.revokeRole(ROLE, AUTHORIZED());
}

//
// renounce_role & renounceRole
//

#[test]
fn test_renounce_role_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED());
    state.renounce_role(ROLE, AUTHORIZED());
}

#[test]
fn test_renounceRole_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED());
    state.renounceRole(ROLE, AUTHORIZED());
}

#[test]
fn test_renounce_role_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());

    state.grant_role(ROLE, AUTHORIZED());

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED());
    state.renounce_role(ROLE, AUTHORIZED());

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED(), AUTHORIZED());

    let has_not_role = !state.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_renounceRole_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());

    state.grantRole(ROLE, AUTHORIZED());

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED());
    state.renounceRole(ROLE, AUTHORIZED());

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED(), AUTHORIZED());

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_renounce_role_multiple_times_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(ROLE, AUTHORIZED());

    start_cheat_caller_address(contract_address, AUTHORIZED());
    state.renounce_role(ROLE, AUTHORIZED());
    state.renounce_role(ROLE, AUTHORIZED());

    let has_not_role = !state.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
fn test_renounceRole_multiple_times_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grantRole(ROLE, AUTHORIZED());

    start_cheat_caller_address(contract_address, AUTHORIZED());
    state.renounceRole(ROLE, AUTHORIZED());
    state.renounceRole(ROLE, AUTHORIZED());

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: ('Can only renounce role for self',))]
fn test_renounce_role_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(ROLE, AUTHORIZED());

    start_cheat_caller_address(contract_address, ZERO());
    state.renounce_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ('Can only renounce role for self',))]
fn test_renounceRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN());
    state.grantRole(ROLE, AUTHORIZED());

    // Admin is unauthorized caller
    state.renounceRole(ROLE, AUTHORIZED());
}

//
// set_role_admin
//

#[test]
fn test_set_role_admin() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = spy_events();

    assert_eq!(state.get_role_admin(ROLE), DEFAULT_ADMIN_ROLE);
    state.set_role_admin(ROLE, OTHER_ROLE);

    spy
        .assert_only_event_role_admin_changed(
            contract_address, ROLE, DEFAULT_ADMIN_ROLE, OTHER_ROLE
        );

    let current_admin_role = state.get_role_admin(ROLE);
    assert_eq!(current_admin_role, OTHER_ROLE);
}

#[test]
fn test_new_admin_can_grant_roles() {
    let mut state = setup();
    let contract_address = test_address();
    state.set_role_admin(ROLE, OTHER_ROLE);

    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(OTHER_ROLE, OTHER_ADMIN());

    start_cheat_caller_address(contract_address, OTHER_ADMIN());
    state.grant_role(ROLE, AUTHORIZED());

    let has_role = state.has_role(ROLE, AUTHORIZED());
    assert!(has_role);
}

#[test]
fn test_new_admin_can_revoke_roles() {
    let mut state = setup();
    let contract_address = test_address();
    state.set_role_admin(ROLE, OTHER_ROLE);

    start_cheat_caller_address(contract_address, ADMIN());
    state.grant_role(OTHER_ROLE, OTHER_ADMIN());

    start_cheat_caller_address(contract_address, OTHER_ADMIN());
    state.grant_role(ROLE, AUTHORIZED());
    state.revoke_role(ROLE, AUTHORIZED());

    let has_not_role = !state.has_role(ROLE, AUTHORIZED());
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_previous_admin_cannot_grant_roles() {
    let mut state = setup();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_caller_address(test_address(), ADMIN());
    state.grant_role(ROLE, AUTHORIZED());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_previous_admin_cannot_revoke_roles() {
    let mut state = setup();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_caller_address(test_address(), ADMIN());
    state.revoke_role(ROLE, AUTHORIZED());
}

//
// Default admin
//

#[test]
fn test_other_role_admin_is_the_default_admin_role() {
    let state = setup();

    let current_admin_role = state.get_role_admin(OTHER_ROLE);
    assert_eq!(current_admin_role, DEFAULT_ADMIN_ROLE);
}

#[test]
fn test_default_admin_role_is_its_own_admin() {
    let state = setup();
    let current_admin_role = state.get_role_admin(DEFAULT_ADMIN_ROLE);
    assert_eq!(current_admin_role, DEFAULT_ADMIN_ROLE);
}

//
// Helpers
//

#[generate_trait]
impl AccessControlSpyHelpersImpl of AccessControlSpyHelpers {
    fn assert_only_event_role_revoked(
        ref self: EventSpy,
        contract: ContractAddress,
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    ) {
        let expected = AccessControlComponent::Event::RoleRevoked(
            RoleRevoked { role, account, sender }
        );
        self.assert_only_event(contract, expected);
    }

    fn assert_only_event_role_granted(
        ref self: EventSpy,
        contract: ContractAddress,
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    ) {
        let expected = AccessControlComponent::Event::RoleGranted(
            RoleGranted { role, account, sender }
        );
        self.assert_only_event(contract, expected);
    }

    fn assert_only_event_role_admin_changed(
        ref self: EventSpy,
        from_address: ContractAddress,
        role: felt252,
        previous_admin_role: felt252,
        new_admin_role: felt252
    ) {
        let expected = AccessControlComponent::Event::RoleAdminChanged(
            RoleAdminChanged { role, previous_admin_role, new_admin_role }
        );
        self.assert_only_event(from_address, expected);
    }
}
