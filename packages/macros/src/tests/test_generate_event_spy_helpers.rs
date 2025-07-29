use cairo_lang_macro::TokenStream;
use indoc::indoc;
use insta::assert_snapshot;

use super::common::format_proc_macro_result;
use crate::generate_event_spy_helpers::definition::generate_event_spy_helpers_q2hsv6hnhh3ug as generate_event_spy_helpers;

#[test]
fn test_event_without_attrs() {
    let input = indoc!(
        "
        {
            pub impl MockContractSpyHelpers {
                event SimpleEvent(
                    field: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_only() {
    let input = indoc!(
        "
        {
            pub impl MockContractSpyHelpers {
                #[only]
                event OnlyEvent(
                    field: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_key() {
    let input = indoc!(
        "
        {
            pub impl ContrMockContractSpyHelpersactSpy {
                event KeyedEvent(
                    #[key]
                    user: ContractAddress,
                    value: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_only_and_key() {
    let input = indoc!(
        "
        {
            pub impl MockContractSpyHelpers {
                #[only]
                event OnlyKeyedEvent(
                    #[key] user: ContractAddress,
                    value: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_invalid_non_default_attr() {
    let input = indoc!(
        "
        {
            pub impl MockContractSpyHelpers {
                #[non_default]
                event InvalidEvent(
                    field: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_impl_without_pub() {
    let input = indoc!(
        "
        {
            impl MockContractSpyHelpers {
                event MockEvent(
                    field: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_empty_impl() {
    let input = indoc!(
        "
        {
            impl MockContractSpyHelpers {}
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_multiple_events() {
    let input = indoc!(
        "
        {
            impl MockContractSpyHelpers {
                event MockEvent(
                    field: u64
                );

                #[only]
                event MockEvent2(
                    field: u64
                );
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_empty_event() {
    let input = indoc!(
        "
        {
            impl MockContractSpyHelpers {
                #[only]
                event EmptyEvent();
            }
        }
        "
    );
    assert_snapshot!(get_string_result(input));
}

fn get_string_result(args_stream: &str) -> String {
    let args_stream = TokenStream::new(args_stream.to_string());
    let raw_result = generate_event_spy_helpers(args_stream);
    format_proc_macro_result(raw_result)
}
