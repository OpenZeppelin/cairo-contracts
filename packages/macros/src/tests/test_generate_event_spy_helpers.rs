use cairo_lang_macro::{quote, TokenStream};
use insta::assert_snapshot;

use super::common::format_proc_macro_result;
use crate::generate_event_spy_helpers::definition::generate_event_spy_helpers_q2hsv6hnhh3ug as generate_event_spy_helpers;

#[test]
fn test_event_without_attrs() {
    let input = quote!(
        {
            pub impl MockContractSpyHelpers {
                event SimpleEvent(
                    field: u64
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_only() {
    let input = quote!(
        {
            pub impl MockContractSpyHelpers {
                #[only]
                event OnlyEvent(
                    field: u64
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_key() {
    let input = quote!(
        {
            pub impl ContrMockContractSpyHelpersactSpy {
                event KeyedEvent(
                    #[key]
                    user: ContractAddress,
                    value: u64
                );
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_event_with_only_and_key() {
    let input = quote!(
        {
            pub impl MockContractSpyHelpers {
                #[only]
                event OnlyKeyedEvent(
                    #[key] user: ContractAddress,
                    value: u64
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
            impl MockContractSpyHelpers {
                event MockEvent(
                    field: u64
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
    );
    assert_snapshot!(get_string_result(input));
}

#[test]
fn test_empty_event() {
    let input = quote!(
        {
            impl MockContractSpyHelpers {
                #[only]
                event EmptyEvent();
            }
        }
    );
    assert_snapshot!(get_string_result(input));
}

fn get_string_result(args_stream: TokenStream) -> String {
    let raw_result = generate_event_spy_helpers(args_stream);
    format_proc_macro_result(raw_result)
}
