use cairo_lang_formatter::format_string;
use cairo_lang_macro::{inline_macro, Diagnostic, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;
use proc_macro2::TokenStream as ProcTokenStream;
use quote::{format_ident, quote};

use crate::{generate_event_spy_helpers::parser, utils::camel_to_snake};

/// Generates helper functions for spying on events in tests.
///
/// Example:
/// ```
/// generate_event_spy_helpers! {
///     impl AccessControlDefaultAdminRulesSpyHelpers {
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
///         let mut keys = array![];
///         keys.append_serde(selector!("DefaultAdminTransferScheduled"));
///         keys.append_serde(new_admin);
///
///         let mut data = array![];
///         data.append_serde(accept_schedule);
///
///         let expected = Event { keys, data };
///         self.assert_only_event(contract, expected);
///     }
///
///     fn assert_only_event_default_admin_transfer_scheduled(
///         ref self: EventSpy,
///         contract: ContractAddress,
///         new_admin: ContractAddress,
///         accept_schedule: u64,
///     ) {
///         self.assert_event_default_admin_transfer_scheduled(contract, new_admin, accept_schedule);
///         self.assert_no_events_left_from(contract);
///     }
/// }
/// ```
#[inline_macro]
pub fn generate_event_spy_helpers(token_stream: TokenStream) -> ProcMacroResult {
    // Parse the arguments
    let impl_block = match parser::parse_dsl(&token_stream.to_string()) {
        Ok((_, impl_block)) => impl_block,
        Err(e) => {
            let error = Diagnostic::error(e.to_string());
            let empty_result = ProcMacroResult::new(TokenStream::empty());
            return empty_result.with_diagnostics(error.into());
        }
    };

    // Generate the helper functions
    let expanded = generate_code(&impl_block).to_string();

    // Format the code
    let db = SimpleParserDatabase::default();
    let formatted_code = format_string(&db, expanded);

    // Return the result
    ProcMacroResult::new(TokenStream::new(formatted_code))
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
fn generate_code(impl_block: &parser::ImplBlock) -> ProcTokenStream {
    let impl_name = format_ident!("{}", impl_block.name);
    let trait_name = format_ident!("{}Trait", impl_block.name);

    let methods: Vec<ProcTokenStream> = impl_block
        .events
        .iter()
        .map(|event| {
            let event_name = &event.name;
            let fn_suffix = format_ident!("{}", camel_to_snake(event_name));
            let selector = event_name.to_string();

            let mut key_fields = vec![];
            let mut data_fields = vec![];

            let mut fn_args = vec![];
            for param in &event.fields {
                let name = format_ident!("{}", param.name);
                let ty = format_ident!("{}", param.ty);
                fn_args.push(quote! { #name: #ty });

                if param.is_key {
                    key_fields.push(quote! { keys.append_serde(#name); });
                } else {
                    data_fields.push(quote! { data.append_serde(#name); });
                }
            }

            let assert_fn_name = format_ident!("assert_event_{}", fn_suffix);
            let only_fn_name = format_ident!("assert_only_event_{}", fn_suffix);
            let fields = event
                .fields
                .iter()
                .map(|p| format_ident!("{}", p.name))
                .collect::<Vec<_>>();

            let assert_only_fn = if event.is_only {
                quote! {
                    fn #only_fn_name(
                        ref self: EventSpy,
                        contract: ContractAddress,
                        #(#fn_args),*
                    ) {
                        self.#assert_fn_name(contract, #(#fields),*);
                        self.assert_no_events_left_from(contract);
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
                    let mut keys = array![];
                    keys.append_serde(selector!(#selector));
                    #(#key_fields)*

                    let mut data = array![];
                    #(#data_fields)*

                    let expected = Event { keys, data };
                    self.assert_only_event(contract, expected);
                }

                #assert_only_fn
            }
        })
        .collect();

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
