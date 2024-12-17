use cairo_lang_macro::{inline_macro, ProcMacroResult, TokenStream};

#[inline_macro]
pub fn echo(token_stream: TokenStream) -> ProcMacroResult {
  ProcMacroResult::new(TokenStream::new("println!(\"{}\", eric);".to_string()))
}
