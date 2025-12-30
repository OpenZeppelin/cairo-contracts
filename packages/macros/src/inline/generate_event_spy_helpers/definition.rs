use cairo_lang_macro::{inline_macro, Diagnostic, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;
use proc_macro2::{Ident, TokenStream as ProcTokenStream};
use quote::{format_ident, quote};

use crate::{
    attribute::common::text_span::merge_spans_from_initial, generate_event_spy_helpers::parser,
    utils::camel_to_snake,
};

/// Generates helper functions for spying on events in tests.
///
/// Example:
/// ```
/// generate_event_spy_helpers! {
///     impl AccessControlDefaultAdminRulesSpyHelpers {
///         #[only]
///         event DefaultAdminTransferScheduled(
///            #[key]
///            new_admin: ContractAddress,
///            accept_schedule: u64
///         );
///     }
/// }
/// ```
///
/// // Generated code:
/// #[generate_trait]
/// impl AccessControlDefaultAdminRulesSpyHelpers of AccessControlDefaultAdminRulesSpyHelpersTrait {
///     fn assert_event_default_admin_transfer_scheduled(
///         ref self: EventSpy,
///         contract: ContractAddress,
///         new_admin: ContractAddress,
///         accept_schedule: u64,
///     ) {
///         let expected = ExpectedEvent::new()
///             .key(selector!("DefaultAdminTransferScheduled"))
///             .key(new_admin)
///             .data(accept_schedule);
///
///         self.assert_emitted_single(contract, expected);
///     }
///
///     fn assert_only_event_default_admin_transfer_scheduled(
///         ref self: EventSpy,
///         contract: ContractAddress,
///         new_admin: ContractAddress,
///         accept_schedule: u64,
///     ) {
///         let expected = ExpectedEvent::new()
///             .key(selector!("DefaultAdminTransferScheduled"))
///             .key(new_admin)
///             .data(accept_schedule);
///
///         self.assert_only_event(contract, expected);
///     }
/// }
/// ```
///
/// Events annotated with `#[only]` receive the additional `assert_only_event_*`
/// helper.
#[inline_macro]
pub fn generate_event_spy_helpers(token_stream: TokenStream) -> ProcMacroResult {
    // 1. Parse the arguments
    let impl_block = match parser::parse_dsl(&token_stream.to_string()) {
        Ok((_, impl_block)) => impl_block,
        Err(e) => {
            let error = Diagnostic::error(e.to_string());
            let empty_result = ProcMacroResult::new(TokenStream::empty());
            return empty_result.with_diagnostics(error.into());
        }
    };

    // 2. Generate the helper functions
    let expanded = generate_code(&impl_block).to_string();

    // 3. Merge spans from the token stream into the expanded code
    let db = SimpleParserDatabase::default();
    let syntax_node_with_spans = merge_spans_from_initial(&token_stream.tokens, &expanded, &db);
    let token_stream_with_spans =
        TokenStream::new(syntax_node_with_spans).with_metadata(token_stream.metadata().clone());
    ProcMacroResult::new(token_stream_with_spans)
}

/// Generates the code for event spy helper functions based on the provided implementation block.
///
/// # Arguments
///
/// * `impl_block` - The parsed implementation block containing event definitions
///
/// # Returns
///
/// A `ProcTokenStream` containing the generated code for event spy helper functions
pub(crate) fn generate_code(impl_block: &parser::ImplBlock) -> ProcTokenStream {
    let impl_name = format_ident!("{}", impl_block.name);
    let trait_name = format_ident!("{}Trait", impl_block.name);

    let methods: Vec<ProcTokenStream> = impl_block.events.iter().map(event_methods).collect();

    let maybe_pub = if impl_block.is_public {
        quote! { pub }
    } else {
        quote! {}
    };

    quote! {
        #[generate_trait]
        #maybe_pub impl #impl_name of #trait_name {
            #(#methods)*
        }
    }
}

fn event_methods(event: &parser::Event) -> ProcTokenStream {
    let event_name = &event.name;
    let fn_suffix = format_ident!("{}", camel_to_snake(event_name));
    let selector = event_name.to_string();

    let (fn_args, key_fields, data_fields) = collect_event_fields(event);
    let expected_for_assert = build_expected_event(&selector, &key_fields, &data_fields);
    let expected_for_only = build_expected_event(&selector, &key_fields, &data_fields);

    let assert_fn_name = format_ident!("assert_event_{}", fn_suffix);
    let only_fn_name = format_ident!("assert_only_event_{}", fn_suffix);

    let assert_only_fn = if event.is_only {
        quote! {
            fn #only_fn_name(
                ref self: EventSpy,
                contract: ContractAddress,
                #(#fn_args),*
            ) {
                let expected = #expected_for_only;
                self.assert_only_event(contract, expected);
            }
        }
    } else {
        quote! {}
    };

    quote! {
        fn #assert_fn_name(
            ref self: EventSpy,
            contract: ContractAddress,
            #(#fn_args),*
        ) {
            let expected = #expected_for_assert;
            self.assert_emitted_single(contract, expected);
        }

        #assert_only_fn
    }
}

fn collect_event_fields(event: &parser::Event) -> (Vec<ProcTokenStream>, Vec<Ident>, Vec<Ident>) {
    let mut fn_args = vec![];
    let mut key_fields = vec![];
    let mut data_fields = vec![];

    for param in &event.fields {
        let name = format_ident!("{}", param.name);
        let ty = format_ident!("{}", param.ty);
        fn_args.push(quote! { #name: #ty });

        if param.is_key {
            key_fields.push(name.clone());
        } else {
            data_fields.push(name.clone());
        }
    }

    (fn_args, key_fields, data_fields)
}

fn build_expected_event(
    selector: &str,
    key_fields: &[Ident],
    data_fields: &[Ident],
) -> ProcTokenStream {
    let mut builder = quote! { ExpectedEvent::new().key(selector!(#selector)) };
    for field in key_fields {
        builder = quote! { #builder.key(#field) };
    }
    for field in data_fields {
        builder = quote! { #builder.data(#field) };
    }
    builder
}
