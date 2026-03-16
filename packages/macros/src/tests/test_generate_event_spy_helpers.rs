use cairo_lang_macro::{quote, TokenStream};
use insta::assert_snapshot;

use super::common::format_proc_macro_result;
use crate::generate_event_spy_helpers::definition::generate_event_spy_helpers_q2hsv6hnhh3ug as generate_event_spy_helpers;

#[test]
fn test_public_impl_generates_basic_event() {
    let input = quote!(
        {
            pub impl TreasurySpyHelpers {
                event FundsReleased(
                    amount: u256
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_only_event_generates_only_helper() {
    let input = quote!(
        {
            impl TreasurySpyHelpers {
                #[only]
                event EmergencyHalt(
                    requester: ContractAddress
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_indexed_fields() {
    let input = quote!(
        {
            pub impl TokenSpyHelpers {
                event Transfer(
                    #[key]
                    from: ContractAddress,
                    #[key]
                    to: ContractAddress,
                    value: u256
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_only_event_with_indexed_fields() {
    let input = quote!(
        {
            impl GovernorSpyHelpers {
                #[only]
                event ProposalExecuted(
                    #[key]
                    proposal_id: felt252,
                    executor: ContractAddress
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_invalid_non_default_attr() {
    let input = quote!(
        {
            pub impl MockContractSpyHelpers {
                #[non_default]
                event InvalidEvent(
                    field: u64
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_impl_without_pub() {
    let input = quote!(
        {
            impl VaultSpyHelpers {
                event WithdrawalQueued(
                    recipient: ContractAddress,
                    amount: u256
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_empty_impl() {
    let input = quote!({
        impl MockContractSpyHelpers {}
    });
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_multiple_events() {
    let input = quote!(
        {
            impl TreasurySpyHelpers {
                event DepositRecorded(
                    depositor: ContractAddress,
                    amount: u256
                );

                #[only]
                event WithdrawalSettled(
                    depositor: ContractAddress,
                    amount: u256
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_empty_event() {
    let input = quote!(
        {
            impl LifecycleSpyHelpers {
                #[only]
                event ContractReset();
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_multiple_keys_and_data() {
    let input = quote!(
        {
            impl ComplexSpyHelpers {
                event ComplexEvent(
                    #[key]
                    first_key: felt252,
                    #[key]
                    second_key: felt252,
                    caller: ContractAddress,
                    amount: u256,
                    memo: felt252
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_only_event_with_mixed_fields() {
    let input = quote!(
        {
            pub impl MixedSpyHelpers {
                #[only]
                event ScheduledEvent(
                    #[key]
                    role: felt252,
                    #[key]
                    account: ContractAddress,
                    sender: ContractAddress,
                    delay: u64,
                    extra: felt252
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_missing_semicolon() {
    let input = quote!(
        {
            impl BrokenHelpers {
                event MissingSemicolon(
                    field: u64
                )
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_missing_event_keyword() {
    let input = quote!(
        {
            impl BrokenHelpers {
                MissingKeywordEvent(
                    field: u64
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

fn get_string_result(args_stream: TokenStream) -> String {
    let raw_result = generate_event_spy_helpers(args_stream);
    format_proc_macro_result(raw_result)
}
