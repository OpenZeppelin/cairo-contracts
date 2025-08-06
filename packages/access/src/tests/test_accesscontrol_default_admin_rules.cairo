use openzeppelin_interfaces::accesscontrol::{
    IACCESSCONTROL_ID, IAccessControl, IAccessControlCamel, IAccessControlWithDelay, RoleStatus,
};
use openzeppelin_interfaces::accesscontrol_default_admin_rules::{
    IACCESSCONTROL_DEFAULT_ADMIN_RULES_ID, IAccessControlDefaultAdminRules,
};
use openzeppelin_interfaces::introspection::ISRC5;
use openzeppelin_test_common::mocks::access::DualCaseAccessControlDefaultAdminRulesMock;
use openzeppelin_test_common::mocks::access::DualCaseAccessControlDefaultAdminRulesMock::INITIAL_DELAY;
use openzeppelin_testing::constants::{
    ADMIN, AUTHORIZED, OTHER, OTHER_ADMIN, OTHER_ROLE, ROLE, TIMESTAMP, ZERO,
};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::{start_cheat_block_timestamp_global, start_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::accesscontrol::extensions::AccessControlDefaultAdminRulesComponent::InternalTrait;
use crate::accesscontrol::extensions::{
    AccessControlDefaultAdminRulesComponent, DEFAULT_ADMIN_ROLE, DefaultConfig,
};
use crate::tests::test_accesscontrol::AccessControlSpyHelpers;

//
// Setup
//

type ComponentState =
    AccessControlDefaultAdminRulesComponent::ComponentState<
        DualCaseAccessControlDefaultAdminRulesMock::ContractState,
    >;

fn CONTRACT_STATE() -> DualCaseAccessControlDefaultAdminRulesMock::ContractState {
    DualCaseAccessControlDefaultAdminRulesMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    AccessControlDefaultAdminRulesComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(INITIAL_DELAY, ADMIN);
    state
}

const ONE_HOUR: u64 = 3600;

//
// initializer
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    state.initializer(INITIAL_DELAY, ADMIN);

    // Check that the default admin role is granted
    let has_role = state.has_role(DEFAULT_ADMIN_ROLE, ADMIN);
    assert!(has_role);

    // Check that the IAccessControl interface is registered
    let supports_iaccesscontrol = CONTRACT_STATE().src5.supports_interface(IACCESSCONTROL_ID);
    assert!(supports_iaccesscontrol);

    // Check that the IAccessControlDefaultAdminRules interface is registered
    let supports_iaccesscontrol_default_admin_rules = CONTRACT_STATE()
        .src5
        .supports_interface(IACCESSCONTROL_DEFAULT_ADMIN_RULES_ID);
    assert!(supports_iaccesscontrol_default_admin_rules);

    // Check that the delay is set
    let delay = state.default_admin_delay();
    assert_eq!(delay, INITIAL_DELAY);
}

#[test]
#[should_panic(expected: 'Invalid default admin')]
fn test_initializer_with_zero_address() {
    let mut state = COMPONENT_STATE();
    state.initializer(INITIAL_DELAY, ZERO);
}

//
// default_admin
//

#[test]
fn test_default_admin() {
    let mut state = setup();
    let default_admin = state.default_admin();
    assert_eq!(default_admin, ADMIN);
}

//
// pending_default_admin
//

#[test]
fn test_pending_default_admin_default_values() {
    let mut state = setup();
    let (pending_default_admin, pending_default_admin_schedule) = state.pending_default_admin();
    assert_eq!(pending_default_admin, ZERO);
    assert_eq!(pending_default_admin_schedule, 0);
}

#[test]
fn test_pending_default_admin_set() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_block_timestamp_global(TIMESTAMP);
    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);
    let (pending_default_admin, pending_default_admin_schedule) = state.pending_default_admin();

    assert_eq!(pending_default_admin, OTHER_ADMIN);
    assert_eq!(pending_default_admin_schedule, TIMESTAMP + INITIAL_DELAY);
}

//
// default_admin_delay
//

#[test]
fn test_default_admin_delay_default_values() {
    let mut state = setup();
    let delay = state.default_admin_delay();
    assert_eq!(delay, INITIAL_DELAY);
}

#[test]
fn test_default_admin_delay_pending_delay_schedule_not_passed() {
    let mut state = setup();
    let new_delay = INITIAL_DELAY + ONE_HOUR;
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.change_default_admin_delay(new_delay);

    // Check that the delay is not changed since the schedule
    // for a delay change has not passed
    let delay = state.default_admin_delay();
    assert_eq!(delay, INITIAL_DELAY);
}

#[test]
fn test_default_admin_delay_pending_delay_schedule_passed() {
    let mut state = setup();
    let new_delay = INITIAL_DELAY + ONE_HOUR;
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.change_default_admin_delay(new_delay);

    // Check that the delay is changed since the schedule
    // for a delay change has passed
    start_cheat_block_timestamp_global(TIMESTAMP + new_delay);
    let delay = state.default_admin_delay();
    assert_eq!(delay, new_delay);
}

//
// pending_default_admin_delay && change_default_admin_delay
//

#[test]
fn test_pending_default_admin_delay_is_not_pending() {
    let mut state = setup();
    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, 0);
    assert_eq!(pending_delay_schedule, 0);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_change_default_admin_delay_unauthorized() {
    let mut state = setup();
    let new_delay = INITIAL_DELAY + ONE_HOUR;
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OTHER);
    state.change_default_admin_delay(new_delay);
}

#[test]
fn test_pending_default_admin_delay_is_pending_increasing_delay() {
    let mut state = setup();
    let new_delay = INITIAL_DELAY + ONE_HOUR;
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.change_default_admin_delay(new_delay);

    // The schedule must be the new delay since the it is increasing
    let expected_schedule = TIMESTAMP + new_delay;
    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, new_delay);
    assert_eq!(pending_delay_schedule, expected_schedule);

    spy
        .assert_only_event_default_admin_delay_change_scheduled(
            contract_address, new_delay, expected_schedule,
        );
}

#[test]
fn test_pending_default_admin_delay_is_pending_decreasing_delay() {
    let mut state = setup();
    let new_delay = INITIAL_DELAY - ONE_HOUR / 2;
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.change_default_admin_delay(new_delay);

    // The schedule must be the difference between the current delay and the new delay
    let expected_schedule = TIMESTAMP + INITIAL_DELAY - new_delay;
    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, new_delay);
    assert_eq!(pending_delay_schedule, expected_schedule);

    spy
        .assert_only_event_default_admin_delay_change_scheduled(
            contract_address, new_delay, expected_schedule,
        );
}

#[test]
fn test_pending_default_admin_delay_increasing_after_schedule_limit() {
    let mut state = setup();
    let new_delay = ONE_HOUR * 24 * 10; // 10 days
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.change_default_admin_delay(new_delay);

    // The schedule must be the limit of the increase wait
    let expected_schedule = TIMESTAMP + DefaultConfig::DEFAULT_ADMIN_DELAY_INCREASE_WAIT;
    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, new_delay);
    assert_eq!(pending_delay_schedule, expected_schedule);

    spy
        .assert_only_event_default_admin_delay_change_scheduled(
            contract_address, new_delay, expected_schedule,
        );
}

//
// begin_default_admin_transfer
//

#[test]
fn test_begin_default_admin_transfer() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.begin_default_admin_transfer(OTHER_ADMIN);

    let expected_schedule = TIMESTAMP + state.default_admin_delay();
    spy
        .assert_only_event_default_admin_transfer_scheduled(
            contract_address, OTHER_ADMIN, expected_schedule,
        );

    let (pending_default_admin, pending_default_admin_schedule) = state.pending_default_admin();
    assert_eq!(pending_default_admin, OTHER_ADMIN);
    assert_eq!(pending_default_admin_schedule, expected_schedule);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_begin_default_admin_transfer_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OTHER);
    state.begin_default_admin_transfer(OTHER_ADMIN);
}

//
// cancel_default_admin_transfer
//

#[test]
fn test_cancel_default_admin_transfer() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);

    let mut spy = spy_events();
    state.cancel_default_admin_transfer();

    spy.assert_only_event_default_admin_transfer_canceled(contract_address);

    let (pending_default_admin, pending_default_admin_schedule) = state.pending_default_admin();
    assert_eq!(pending_default_admin, ZERO);
    assert_eq!(pending_default_admin_schedule, 0);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_cancel_default_admin_transfer_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OTHER);
    state.cancel_default_admin_transfer();
}

//
// accept_default_admin_transfer
//

#[test]
fn test_accept_default_admin_transfer() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_block_timestamp_global(TIMESTAMP);

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, OTHER_ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP + state.default_admin_delay());
    state.accept_default_admin_transfer();

    spy.assert_event_role_revoked(contract_address, DEFAULT_ADMIN_ROLE, ADMIN, OTHER_ADMIN);
    spy
        .assert_only_event_role_granted(
            contract_address, DEFAULT_ADMIN_ROLE, OTHER_ADMIN, OTHER_ADMIN,
        );

    let has_role = state.has_role(DEFAULT_ADMIN_ROLE, OTHER_ADMIN);
    assert!(has_role);

    let has_not_role = !state.has_role(DEFAULT_ADMIN_ROLE, ADMIN);
    assert!(has_not_role);

    let (pending_default_admin, pending_default_admin_schedule) = state.pending_default_admin();
    assert_eq!(pending_default_admin, ZERO);
    assert_eq!(pending_default_admin_schedule, 0);
}

#[test]
#[should_panic(expected: 'Only new default admin allowed')]
fn test_accept_default_admin_transfer_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);

    start_cheat_caller_address(contract_address, OTHER);
    state.accept_default_admin_transfer();
}

#[test]
#[should_panic(expected: 'Default admin delay enforced')]
fn test_accept_default_admin_transfer_unauthorized_when_schedule_not_passed() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);

    start_cheat_caller_address(contract_address, OTHER_ADMIN);
    state.accept_default_admin_transfer();
}

//
// rollback_default_admin_delay
//

#[test]
fn test_rollback_default_admin_delay() {
    let mut state = setup();
    let new_delay = ONE_HOUR * 24 * 1; // 1 day
    let contract_address = test_address();

    start_cheat_block_timestamp_global(TIMESTAMP);
    start_cheat_caller_address(contract_address, ADMIN);
    state.change_default_admin_delay(new_delay);

    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, new_delay);
    assert_eq!(pending_delay_schedule, TIMESTAMP + new_delay);

    start_cheat_caller_address(contract_address, ADMIN);
    let mut spy = spy_events();
    state.rollback_default_admin_delay();

    spy.assert_only_event_default_admin_delay_change_canceled(contract_address);

    let (pending_delay, pending_delay_schedule) = state.pending_default_admin_delay();
    assert_eq!(pending_delay, 0);
    assert_eq!(pending_delay_schedule, 0);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_rollback_default_admin_delay_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.change_default_admin_delay(ONE_HOUR);

    start_cheat_caller_address(contract_address, OTHER);
    state.rollback_default_admin_delay();
}

//
// default_admin_delay_increase_wait
//

#[test]
fn test_default_admin_delay_increase_wait() {
    let state = setup();
    let wait = state.default_admin_delay_increase_wait();
    assert_eq!(wait, DefaultConfig::DEFAULT_ADMIN_DELAY_INCREASE_WAIT);
}

//
// has_role & hasRole
//

#[test]
fn test_has_role() {
    let mut state = setup();
    assert!(!state.has_role(ROLE, AUTHORIZED));
    state._grant_role(ROLE, AUTHORIZED);
    assert!(state.has_role(ROLE, AUTHORIZED));
}

#[test]
fn test_hasRole() {
    let mut state = setup();
    assert!(!state.hasRole(ROLE, AUTHORIZED));
    state._grant_role(ROLE, AUTHORIZED);
    assert!(state.hasRole(ROLE, AUTHORIZED));
}

//
// assert_only_role
//

#[test]
fn test_assert_only_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(ROLE, AUTHORIZED);

    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.assert_only_role(ROLE);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_assert_only_role_unauthorized() {
    let state = setup();
    start_cheat_caller_address(test_address(), OTHER);
    state.assert_only_role(ROLE);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_assert_only_role_unauthorized_when_authorized_for_another_role() {
    let mut state = setup();
    state.grant_role(ROLE, AUTHORIZED);

    start_cheat_caller_address(test_address(), AUTHORIZED);
    state.assert_only_role(OTHER_ROLE);
}

//
// grant_role & grantRole
//

#[test]
#[should_panic(expected: 'Default admin rules enforced')]
fn test_grant_role_default_admin_role() {
    let mut state = setup();
    state.grant_role(DEFAULT_ADMIN_ROLE, AUTHORIZED);
}

#[test]
fn test_grant_role() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(ROLE, AUTHORIZED);

    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert!(has_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
fn test_grantRole() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grantRole(ROLE, AUTHORIZED);

    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_role = state.hasRole(ROLE, AUTHORIZED);
    assert!(has_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
fn test_grant_role_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);

    state.grant_role(ROLE, AUTHORIZED);
    state.grant_role(ROLE, AUTHORIZED);
    assert!(state.has_role(ROLE, AUTHORIZED));
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
fn test_grant_role_when_delayed() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    state.grant_role(ROLE, AUTHORIZED);
    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert!(has_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
fn test_grantRole_when_delayed() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    state.grantRole(ROLE, AUTHORIZED);
    spy.assert_only_event_role_granted(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert!(has_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
fn test_grantRole_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);

    state.grantRole(ROLE, AUTHORIZED);
    state.grantRole(ROLE, AUTHORIZED);
    assert!(state.hasRole(ROLE, AUTHORIZED));
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_grant_role_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED);
    state.grant_role(ROLE, AUTHORIZED);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_grantRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED);
    state.grantRole(ROLE, AUTHORIZED);
}

//
// grant_role_with_delay
//

#[test]
#[should_panic(expected: 'Default admin rules enforced')]
fn test_grant_role_with_delay_default_admin_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);

    state.grant_role_with_delay(DEFAULT_ADMIN_ROLE, AUTHORIZED, ONE_HOUR);
}

#[test]
fn test_grant_role_with_delay() {
    let mut state = setup();
    let mut spy = spy_events();
    let delay = ONE_HOUR;
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);

    state.grant_role_with_delay(ROLE, AUTHORIZED, delay);
    spy.assert_only_event_role_granted_with_delay(contract_address, ROLE, AUTHORIZED, ADMIN, delay);

    // Right after granting the role
    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert_eq!(has_role, false);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Delayed(TIMESTAMP + delay));
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);

    // When the delay has passed
    start_cheat_block_timestamp_global(TIMESTAMP + delay);
    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert_eq!(has_role, true);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::Effective);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), true);
}

#[test]
#[should_panic(expected: 'Delay must be greater than 0')]
fn test_grant_role_with_zero_delay() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role_with_delay(ROLE, AUTHORIZED, 0);
}

#[test]
#[should_panic(expected: 'Role is already effective')]
fn test_grant_role_with_delay_when_already_effective() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role(ROLE, AUTHORIZED);
    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_grant_role_with_delay_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);
}

//
// revoke_role & revokeRole
//

#[test]
#[should_panic(expected: 'Default admin rules enforced')]
fn test_revoke_role_default_admin_role() {
    let mut state = setup();
    state.revoke_role(DEFAULT_ADMIN_ROLE, AUTHORIZED);
}

#[test]
fn test_revoke_role_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);
    state.revoke_role(ROLE, AUTHORIZED);
}

#[test]
fn test_revokeRole_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);
    state.revokeRole(ROLE, AUTHORIZED);
}

#[test]
fn test_revoke_role_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);

    state.grant_role(ROLE, AUTHORIZED);

    let mut spy = spy_events();
    state.revoke_role(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
fn test_revokeRole_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);

    state.grantRole(ROLE, AUTHORIZED);

    let mut spy = spy_events();
    state.revokeRole(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
fn test_revoke_role_for_delayed_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);

    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    state.revoke_role(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
fn test_revokeRole_for_delayed_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);

    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    state.revokeRole(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, ADMIN);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
fn test_revoke_role_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);

    state.grant_role(ROLE, AUTHORIZED);
    state.revoke_role(ROLE, AUTHORIZED);
    state.revoke_role(ROLE, AUTHORIZED);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
fn test_revokeRole_multiple_times_for_granted_role() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);

    state.grantRole(ROLE, AUTHORIZED);
    state.revokeRole(ROLE, AUTHORIZED);
    state.revokeRole(ROLE, AUTHORIZED);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
    assert_eq!(state.get_role_status(ROLE, AUTHORIZED), RoleStatus::NotGranted);
    assert_eq!(state.is_role_granted(ROLE, AUTHORIZED), false);
    assert_eq!(state.is_role_effective(ROLE, AUTHORIZED), false);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_revoke_role_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER);
    state.revoke_role(ROLE, AUTHORIZED);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_revokeRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER);
    state.revokeRole(ROLE, AUTHORIZED);
}

//
// renounce_role & renounceRole
//

#[test]
fn test_renounce_role_default_admin_role() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_block_timestamp_global(TIMESTAMP);
    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(ZERO);

    let has_role = state.has_role(DEFAULT_ADMIN_ROLE, ADMIN);
    assert!(has_role);

    let mut spy = spy_events();
    start_cheat_block_timestamp_global(TIMESTAMP + ONE_HOUR);
    state.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN);

    spy.assert_only_event_role_revoked(contract_address, DEFAULT_ADMIN_ROLE, ADMIN, ADMIN);

    let has_not_role = !state.has_role(DEFAULT_ADMIN_ROLE, ADMIN);
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: 'Default admin delay enforced')]
fn test_renounce_role_default_admin_role_pending_admin_schedule_not_set() {
    let mut state = setup();
    state.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN);
}

#[test]
#[should_panic(expected: 'Default admin delay enforced')]
fn test_renounce_role_default_admin_role_pending_admin_not_zero() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(OTHER_ADMIN);
    state.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN);
}

#[test]
#[should_panic(expected: 'Default admin delay enforced')]
fn test_renounce_role_default_admin_role_pending_admin_schedule_not_passed() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, ADMIN);
    state.begin_default_admin_transfer(ZERO);

    // Default admin delay (one hour) is not passed yet
    state.renounce_role(DEFAULT_ADMIN_ROLE, ADMIN);
}

#[test]
fn test_renounce_role_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED);
    state.renounce_role(ROLE, AUTHORIZED);
}

#[test]
fn test_renounceRole_for_role_not_granted() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), AUTHORIZED);
    state.renounceRole(ROLE, AUTHORIZED);
}

#[test]
fn test_renounce_role_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);

    state.grant_role(ROLE, AUTHORIZED);

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounce_role(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, AUTHORIZED);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
fn test_renounceRole_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);

    state.grantRole(ROLE, AUTHORIZED);

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounceRole(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, AUTHORIZED);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
fn test_renounce_role_for_delayed_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);

    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounce_role(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, AUTHORIZED);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
fn test_renounceRole_for_delayed_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);

    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);

    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounceRole(ROLE, AUTHORIZED);

    spy.assert_only_event_role_revoked(contract_address, ROLE, AUTHORIZED, AUTHORIZED);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
fn test_renounce_role_multiple_times_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(ROLE, AUTHORIZED);

    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounce_role(ROLE, AUTHORIZED);
    state.renounce_role(ROLE, AUTHORIZED);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
fn test_renounceRole_multiple_times_for_granted_role() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grantRole(ROLE, AUTHORIZED);

    start_cheat_caller_address(contract_address, AUTHORIZED);
    state.renounceRole(ROLE, AUTHORIZED);
    state.renounceRole(ROLE, AUTHORIZED);

    let has_not_role = !state.hasRole(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: 'Can only renounce role for self')]
fn test_renounce_role_unauthorized() {
    let mut state = setup();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(ROLE, AUTHORIZED);

    start_cheat_caller_address(contract_address, ZERO);
    state.renounce_role(ROLE, AUTHORIZED);
}

#[test]
#[should_panic(expected: 'Can only renounce role for self')]
fn test_renounceRole_unauthorized() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), ADMIN);
    state.grantRole(ROLE, AUTHORIZED);

    // Admin is unauthorized caller
    state.renounceRole(ROLE, AUTHORIZED);
}

//
// set_role_admin
//

#[test]
#[should_panic(expected: 'Default admin rules enforced')]
fn test_set_role_admin_default_admin_role() {
    let mut state = setup();
    state.set_role_admin(DEFAULT_ADMIN_ROLE, OTHER_ROLE);
}

#[test]
fn test_set_role_admin() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = spy_events();

    assert_eq!(state.get_role_admin(ROLE), DEFAULT_ADMIN_ROLE);
    state.set_role_admin(ROLE, OTHER_ROLE);

    spy
        .assert_only_event_role_admin_changed(
            contract_address, ROLE, DEFAULT_ADMIN_ROLE, OTHER_ROLE,
        );

    let current_admin_role = state.get_role_admin(ROLE);
    assert_eq!(current_admin_role, OTHER_ROLE);
}

#[test]
fn test_new_admin_can_grant_roles() {
    let mut state = setup();
    let contract_address = test_address();
    state.set_role_admin(ROLE, OTHER_ROLE);

    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(OTHER_ROLE, OTHER_ADMIN);

    start_cheat_caller_address(contract_address, OTHER_ADMIN);
    state.grant_role(ROLE, AUTHORIZED);

    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert!(has_role);
}

#[test]
fn test_new_admin_can_grant_roles_with_delay() {
    let mut state = setup();
    let contract_address = test_address();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_block_timestamp_global(TIMESTAMP);

    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(OTHER_ROLE, OTHER_ADMIN);

    let delay = ONE_HOUR;
    start_cheat_caller_address(contract_address, OTHER_ADMIN);
    state.grant_role_with_delay(ROLE, AUTHORIZED, delay);

    start_cheat_block_timestamp_global(TIMESTAMP + delay);
    let has_role = state.has_role(ROLE, AUTHORIZED);
    assert!(has_role);
}

#[test]
fn test_new_admin_can_revoke_roles() {
    let mut state = setup();
    let contract_address = test_address();
    state.set_role_admin(ROLE, OTHER_ROLE);

    start_cheat_caller_address(contract_address, ADMIN);
    state.grant_role(OTHER_ROLE, OTHER_ADMIN);

    start_cheat_caller_address(contract_address, OTHER_ADMIN);
    state.grant_role(ROLE, AUTHORIZED);
    state.revoke_role(ROLE, AUTHORIZED);

    let has_not_role = !state.has_role(ROLE, AUTHORIZED);
    assert!(has_not_role);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_previous_admin_cannot_grant_roles() {
    let mut state = setup();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_caller_address(test_address(), ADMIN);
    state.grant_role(ROLE, AUTHORIZED);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_previous_admin_cannot_grant_roles_with_delay() {
    let mut state = setup();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_caller_address(test_address(), ADMIN);
    start_cheat_block_timestamp_global(TIMESTAMP);
    state.grant_role_with_delay(ROLE, AUTHORIZED, ONE_HOUR);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_previous_admin_cannot_revoke_roles() {
    let mut state = setup();
    state.set_role_admin(ROLE, OTHER_ROLE);
    start_cheat_caller_address(test_address(), ADMIN);
    state.revoke_role(ROLE, AUTHORIZED);
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
impl AccessControlDefaultAdminRulesSpyHelpersImpl of AccessControlDefaultAdminRulesSpyHelpers {
    fn assert_only_event_default_admin_transfer_scheduled(
        ref self: EventSpy,
        contract: ContractAddress,
        new_admin: ContractAddress,
        accept_schedule: u64,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("DefaultAdminTransferScheduled"))
            .key(new_admin)
            .data(accept_schedule);

        self.assert_only_event(contract, expected);
    }

    fn assert_only_event_default_admin_transfer_canceled(
        ref self: EventSpy, contract: ContractAddress,
    ) {
        let expected = ExpectedEvent::new().key(selector!("DefaultAdminTransferCanceled"));

        self.assert_only_event(contract, expected);
    }

    fn assert_only_event_default_admin_delay_change_scheduled(
        ref self: EventSpy, contract: ContractAddress, new_delay: u64, effect_schedule: u64,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("DefaultAdminDelayChangeScheduled"))
            .data(new_delay)
            .data(effect_schedule);

        self.assert_only_event(contract, expected);
    }

    fn assert_only_event_default_admin_delay_change_canceled(
        ref self: EventSpy, contract: ContractAddress,
    ) {
        let expected = ExpectedEvent::new().key(selector!("DefaultAdminDelayChangeCanceled"));

        self.assert_only_event(contract, expected);
    }
}
