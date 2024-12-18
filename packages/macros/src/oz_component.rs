use cairo_lang_macro::{attribute_macro, Diagnostic, Diagnostics, ProcMacroResult, TokenStream};
use regex::Regex;

/// List of the accepted components.
const OZ_COMPONENTS: [&str; 1] = ["ERC20"];

/// Inserts a component dependency into a modules codebase.
#[attribute_macro]
pub fn oz_component(attribute_stream: TokenStream, item_stream: TokenStream) -> ProcMacroResult {
    let args = parse_args(&attribute_stream.to_string());

    if args.len() != 1 {
        return ProcMacroResult::new(TokenStream::empty())
            .with_diagnostics(Diagnostic::error("Invalid number of arguments").into());
    }

    ProcMacroResult::new(TokenStream::empty())
}

/// Parses the arguments from the attribute stream.
fn parse_args(text: &str) -> Vec<String> {
    let re = Regex::new(r"(\w+)").unwrap();
    let matches = re.find_iter(text);
    matches.map(|m| m.as_str().to_string()).collect()
}

fn get_component_info(name: &str) -> (ComponentInfo, Diagnostics) {
    match name {
        "ERC20" => ComponentInfo {
            name: name.to_string(),
            path: format!("openzeppelin_token::erc20::ERC20Component"),
            storage: format!("ERC20Storage"),
            event: format!("ERC20Event"),
        },
        _ => panic!("Invalid component name"),
    }
}

/// Information about a component.
///
/// # Members
///
/// * `name` - The name of the component (e.g. `ERC20Component`)
/// * `path` - The path from where the component is imported (e.g. `openzeppelin_token::erc20::ERC20Component`)
/// * `storage` - The path to reference the component in storage (e.g. `ERC20Storage`)
/// * `event` - The path to reference the component events (e.g. `ERC20Event`)
pub struct ComponentInfo {
    pub name: String,
    pub path: String,
    pub storage: String,
    pub event: String,
}
