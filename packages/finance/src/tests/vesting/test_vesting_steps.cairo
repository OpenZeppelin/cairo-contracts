use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_finance::tests::mocks::vesting_mocks::StepsVestingMock;
use openzeppelin_finance::tests::vesting::helpers::{VestingStrategy, TestData, setup};
use openzeppelin_finance::vesting::interface::{IVestingDispatcher, IVestingDispatcherTrait};
use openzeppelin_finance::vesting::vesting::VestingComponent::InternalImpl;
use openzeppelin_finance::vesting::vesting::VestingComponent;
use openzeppelin_test_common::vesting::VestingSpyHelpers;
use openzeppelin_testing::constants::OWNER;
use openzeppelin_testing::events::EventSpyExt;
use snforge_std::{spy_events, start_cheat_caller_address, cheat_block_timestamp_global};
use starknet::ContractAddress;

//
// Setup
//

type ComponentState = VestingComponent::ComponentState<StepsVestingMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    VestingComponent::component_state_for_testing()
}

const TOTAL_STEPS: u64 = 10;

impl DefaultTestData of Default<TestData> {
    fn default() -> TestData {
        TestData {
            strategy: VestingStrategy::Steps(TOTAL_STEPS),
            total_allocation: 200,
            beneficiary: OWNER(),
            start: 30,
            duration: 100,
            cliff_duration: 0
        }
    }
}

//
// initializer
//

#[test]
fn test_state_after_init() {
    let data = Default::default();
    let (vesting, _) = setup(data);

    assert_eq!(vesting.start(), data.start);
    assert_eq!(vesting.duration(), data.duration);
    assert_eq!(vesting.cliff(), data.start + data.cliff_duration);
    assert_eq!(vesting.end(), data.start + data.duration);
    let beneficiary = IOwnableDispatcher { contract_address: vesting.contract_address }.owner();
    assert_eq!(beneficiary, data.beneficiary);
}

#[test]
#[should_panic(expected: ('Vesting: Invalid cliff duration',))]
fn test_init_invalid_cliff_value() {
    let mut component_state = COMPONENT_STATE();
    let mut data: TestData = Default::default();
    data.cliff_duration = data.duration + 1;

    component_state.initializer(data.start, data.duration, data.cliff_duration);
}

#[test]
fn test_vesting_schedule_no_cliff() {
    let data = Default::default();
    let (vesting, token) = setup(data);
    let tokens_per_step = data.total_allocation / TOTAL_STEPS.into();
    let step_duration = data.duration / TOTAL_STEPS;

    let mut time_passed = 0;
    while time_passed <= data.duration {
        let steps_passed = time_passed / step_duration;
        let expected_vested_amount = tokens_per_step * steps_passed.into();
        let actual_vested_amount = vesting.vested_amount(token, data.start + time_passed);
        assert_eq!(actual_vested_amount, expected_vested_amount);

        time_passed += 1;
    };

    let end_timestamp = data.start + data.duration;
    assert_eq!(vesting.vested_amount(token, end_timestamp), data.total_allocation);
}

#[test]
fn test_vesting_schedule_with_cliff() {
    let mut data: TestData = Default::default();
    data.cliff_duration = 30;
    let (vesting, token) = setup(data);
    let tokens_per_step = data.total_allocation / TOTAL_STEPS.into();
    let step_duration = data.duration / TOTAL_STEPS;

    let mut time_passed = 0;
    while time_passed < data.cliff_duration {
        let actual_vested_amount = vesting.vested_amount(token, data.start + time_passed);
        assert_eq!(actual_vested_amount, 0);

        time_passed += 1;
    };

    while time_passed <= data.duration {
        let steps_passed = time_passed / step_duration;
        let expected_vested_amount = tokens_per_step * steps_passed.into();
        let actual_vested_amount = vesting.vested_amount(token, data.start + time_passed);
        assert_eq!(actual_vested_amount, expected_vested_amount);

        time_passed += 1;
    };

    let end_timestamp = data.start + data.duration;
    assert_eq!(vesting.vested_amount(token, end_timestamp), data.total_allocation);
}

#[test]
fn test_release_single_call_within_duration() {
    let data = Default::default();
    let (vesting, token) = setup(data);
    start_cheat_caller_address(vesting.contract_address, data.beneficiary);

    let tokens_per_step = data.total_allocation / TOTAL_STEPS.into();
    let time_passed = 42; // 4 full steps passed
    let expected_release_amount = 4 * tokens_per_step;
    cheat_block_timestamp_global(data.start + time_passed);
    let mut spy = spy_events();

    assert_eq!(vesting.released(token), 0);
    assert_eq!(vesting.releasable(token), expected_release_amount);

    let actual_release_amount = vesting.release(token);
    assert_eq!(actual_release_amount, expected_release_amount);

    assert_eq!(vesting.released(token), expected_release_amount);
    assert_eq!(vesting.releasable(token), 0);

    spy.drop_event(); // Drops Transfer event from ERC20 mock
    spy.assert_only_event_amount_released(vesting.contract_address, token, expected_release_amount);
}

#[test]
fn test_release_single_call_after_end() {
    let data = Default::default();
    let (vesting, token) = setup(data);
    start_cheat_caller_address(vesting.contract_address, data.beneficiary);

    let time_passed = data.duration + 1;
    cheat_block_timestamp_global(data.start + time_passed);
    let mut spy = spy_events();

    assert_eq!(vesting.released(token), 0);
    assert_eq!(vesting.releasable(token), data.total_allocation);

    let actual_release_amount = vesting.release(token);
    assert_eq!(actual_release_amount, data.total_allocation);

    assert_eq!(vesting.released(token), data.total_allocation);
    assert_eq!(vesting.releasable(token), 0);

    spy.drop_event(); // Drops Transfer event from ERC20 mock
    spy.assert_only_event_amount_released(vesting.contract_address, token, data.total_allocation);
}

#[test]
fn test_release_multiple_calls() {
    let mut data: TestData = Default::default();
    data.cliff_duration = 30;
    let (vesting, token) = setup(data);
    start_cheat_caller_address(vesting.contract_address, data.beneficiary);

    // 1. Before cliff ended
    cheat_block_timestamp_global(vesting.cliff() - 1);
    assert_eq!(vesting.released(token), 0);
    assert_eq!(vesting.releasable(token), 0);

    vesting.release(token);

    assert_eq!(vesting.released(token), 0);
    assert_eq!(vesting.releasable(token), 0);

    // 2. When the cliff ended
    cheat_block_timestamp_global(vesting.cliff());
    assert_eq!(vesting.released(token), 0);
    assert_eq!(vesting.releasable(token), 60);

    vesting.release(token);

    assert_eq!(vesting.released(token), 60);
    assert_eq!(vesting.releasable(token), 0);

    // 3. When 44/100 seconds passed
    cheat_block_timestamp_global(data.start + 44);
    assert_eq!(vesting.released(token), 60);
    assert_eq!(vesting.releasable(token), 20);

    vesting.release(token);

    assert_eq!(vesting.released(token), 80);
    assert_eq!(vesting.releasable(token), 0);

    // 3. After the vesting ended
    cheat_block_timestamp_global(data.start + data.duration + 1);
    assert_eq!(vesting.released(token), 80);
    assert_eq!(vesting.releasable(token), 120);

    vesting.release(token);

    assert_eq!(vesting.released(token), data.total_allocation);
    assert_eq!(vesting.releasable(token), 0);
}
