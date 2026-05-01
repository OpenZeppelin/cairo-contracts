//! Token stream helpers shared by procedural macro entry points.
//!
//! Scarb's V2 macro API passes token streams with real token boundaries and spans. These helpers
//! keep macro entry points focused on their domain logic while centralizing parser diagnostics and
//! generated-code tokenization.

use cairo_lang_filesystem::{
    ids::CodeMapping,
    span::{TextSpan as CairoTextSpan, TextWidth},
};
use cairo_lang_macro::{
    quote, Diagnostic, TextSpan, Token, TokenStream, TokenStreamMetadata, TokenTree,
};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::{with_db::SyntaxNodeWithDb, SyntaxNode};

/// Parses a Scarb-provided macro input token stream as a full Cairo syntax file.
///
/// Scarb guarantees that token streams passed to procedural macros are safe to parse with
/// `parse_token_stream`, which preserves the V2 token/span model better than converting the input
/// to a string and reparsing it as virtual source.
pub fn parse_macro_input<'db>(
    db: &'db SimpleParserDatabase,
    token_stream: &TokenStream,
) -> Result<SyntaxNode<'db>, Diagnostic> {
    let (node, diagnostics) = db.parse_token_stream(token_stream);
    if diagnostics.check_error_free().is_ok() {
        Ok(node)
    } else {
        Err(Diagnostic::error(diagnostics.format(db)))
    }
}

/// Parses macro-generated Cairo code and converts parser failures into plugin diagnostics.
pub fn parse_generated_code<'db>(
    db: &'db SimpleParserDatabase,
    code: impl ToString,
) -> Result<SyntaxNode<'db>, Diagnostic> {
    db.parse_virtual(code)
        .map_err(|diagnostics| Diagnostic::error(diagnostics.format(db)))
}

/// Builds a token stream from generated Cairo code.
///
/// Generated code does not originate from a user file. Assigning call-site spans makes diagnostics
/// point to the macro invocation instead of trying to reuse arbitrary spans from matching token
/// text in the input.
pub fn generated_code_token_stream(
    db: &SimpleParserDatabase,
    code: impl ToString,
    metadata: TokenStreamMetadata,
) -> Result<TokenStream, Diagnostic> {
    let syntax_node = parse_generated_code(db, code)?;
    let syntax_node = SyntaxNodeWithDb::new(&syntax_node, db);
    let token_stream = quote! { #syntax_node };
    Ok(with_call_site_spans(token_stream).with_metadata(metadata))
}

/// Builds a token stream from patched Cairo code while preserving copied-source spans.
///
/// Cairo's patch builder can tell which parts of a rewritten module came from the original source.
/// We use those mappings for copied tokens and assign call-site spans to macro-generated tokens.
/// This keeps user-written errors inside an annotated item anchored to their original line without
/// pretending generated helper code was written by the user.
pub fn mapped_code_token_stream(
    db: &SimpleParserDatabase,
    code: impl ToString,
    code_mappings: &[CodeMapping],
    metadata: TokenStreamMetadata,
) -> Result<TokenStream, Diagnostic> {
    let syntax_node = parse_generated_code(db, code)?;
    let syntax_node = SyntaxNodeWithDb::new(&syntax_node, db);
    let token_stream = quote! { #syntax_node };
    Ok(with_mapped_or_call_site_spans(token_stream, code_mappings).with_metadata(metadata))
}

/// Appends generated Cairo code to an existing token stream while preserving the existing tokens.
pub fn append_generated_code(
    db: &SimpleParserDatabase,
    mut base: TokenStream,
    code: impl ToString,
) -> Result<TokenStream, Diagnostic> {
    let generated = generated_code_token_stream(db, code, base.metadata().clone())?;
    base.extend(generated);
    Ok(base)
}

/// Rebuilds all tokens with call-site spans while preserving token text and order.
fn with_call_site_spans(token_stream: TokenStream) -> TokenStream {
    let tokens = token_stream
        .tokens
        .iter()
        .map(|token_tree| {
            let TokenTree::Ident(token) = token_tree;
            TokenTree::Ident(Token::new(token.content.as_ref(), TextSpan::call_site()))
        })
        .collect();
    TokenStream::new(tokens)
}

fn with_mapped_or_call_site_spans(
    token_stream: TokenStream,
    code_mappings: &[CodeMapping],
) -> TokenStream {
    let tokens = token_stream
        .tokens
        .iter()
        .map(|token_tree| {
            let TokenTree::Ident(token) = token_tree;
            let span = translate_copied_source_span(&token.span, code_mappings)
                .unwrap_or_else(TextSpan::call_site);
            TokenTree::Ident(Token::new(token.content.as_ref(), span))
        })
        .collect();
    TokenStream::new(tokens)
}

fn translate_copied_source_span(
    token_span: &TextSpan,
    code_mappings: &[CodeMapping],
) -> Option<TextSpan> {
    let mapped_span = CairoTextSpan::new(
        TextWidth::new_for_testing(token_span.start).as_offset(),
        TextWidth::new_for_testing(token_span.end).as_offset(),
    );

    code_mappings.iter().find_map(|mapping| {
        mapping
            .translate(mapped_span)
            .map(|translated| TextSpan::new(translated.start.as_u32(), translated.end.as_u32()))
    })
}
