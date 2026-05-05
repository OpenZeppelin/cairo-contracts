//! Token stream helpers shared by procedural macro entry points.
//!
//! Scarb's V2 macro API passes token streams with real token boundaries and spans. These helpers
//! keep macro entry points focused on their domain logic while centralizing parser diagnostics and
//! generated-code tokenization.

use cairo_lang_filesystem::{
    ids::{CodeMapping, CodeOrigin},
    span::{TextOffset, TextSpan as CairoTextSpan, TextWidth},
};
use cairo_lang_macro::{
    quote, Diagnostic, Diagnostics, Severity, TextSpan, Token, TokenStream, TokenStreamMetadata,
    TokenTree,
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
) -> Result<SyntaxNode<'db>, Diagnostics> {
    let (node, diagnostics) = db.parse_token_stream(token_stream);
    if diagnostics.check_error_free().is_ok() {
        Ok(node)
    } else {
        let diagnostics = diagnostics
            .format_with_severity(db, &Default::default())
            .into_iter()
            .map(|diagnostic| {
                Diagnostic::new(
                    macro_severity(diagnostic.severity().to_string()),
                    diagnostic.message(),
                )
            })
            .collect::<Vec<_>>();
        Err(Diagnostics::new(diagnostics))
    }
}

/// Parses macro-generated Cairo code and converts parser failures into plugin diagnostics.
pub fn parse_generated_code<'db>(
    db: &'db SimpleParserDatabase,
    code: impl ToString,
) -> Result<SyntaxNode<'db>, Diagnostics> {
    db.parse_virtual(code).map_err(|diagnostics| {
        let diagnostics = diagnostics
            .format_with_severity(db, &Default::default())
            .into_iter()
            .map(|diagnostic| {
                Diagnostic::new(
                    macro_severity(diagnostic.severity().to_string()),
                    diagnostic.message(),
                )
            })
            .collect::<Vec<_>>();
        Diagnostics::new(diagnostics)
    })
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
) -> Result<TokenStream, Diagnostics> {
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
) -> Result<TokenStream, Diagnostics> {
    let code = code.to_string();
    let syntax_node = parse_generated_code(db, &code)?;
    let syntax_node = SyntaxNodeWithDb::new(&syntax_node, db);
    let token_stream = quote! { #syntax_node };
    Ok(with_mapped_or_call_site_spans(token_stream, &code, code_mappings).with_metadata(metadata))
}

/// Appends generated Cairo code to an existing token stream while preserving the existing tokens.
pub fn append_generated_code(
    db: &SimpleParserDatabase,
    mut base: TokenStream,
    code: impl ToString,
) -> Result<TokenStream, Diagnostics> {
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
    code: &str,
    code_mappings: &[CodeMapping],
) -> TokenStream {
    let tokens = token_stream
        .tokens
        .iter()
        .map(|token_tree| {
            let TokenTree::Ident(token) = token_tree;
            let span = translate_copied_source_span(&token.span, code, code_mappings)
                .unwrap_or_else(TextSpan::call_site);
            TokenTree::Ident(Token::new(token.content.as_ref(), span))
        })
        .collect();
    TokenStream::new(tokens)
}

fn translate_copied_source_span(
    token_span: &TextSpan,
    code: &str,
    code_mappings: &[CodeMapping],
) -> Option<TextSpan> {
    let mapped_span = CairoTextSpan::new(
        source_offset(code, token_span.start)?,
        source_offset(code, token_span.end)?,
    );

    code_mappings.iter().find_map(|mapping| {
        if matches!(mapping.origin, CodeOrigin::Start(_)) {
            mapping
                .translate(mapped_span)
                .map(|translated| TextSpan::new(translated.start.as_u32(), translated.end.as_u32()))
        } else {
            None
        }
    })
}

fn source_offset(code: &str, offset: u32) -> Option<TextOffset> {
    let index = usize::try_from(offset).ok()?;
    code.is_char_boundary(index)
        .then(|| TextWidth::at(code, index).as_offset())
}

fn macro_severity(severity: String) -> Severity {
    match severity.as_str() {
        "warning" => Severity::Warning,
        _ => Severity::Error,
    }
}

#[cfg(test)]
mod tests {
    use super::translate_copied_source_span;
    use cairo_lang_filesystem::{
        ids::{CodeMapping, CodeOrigin},
        span::{TextSpan as CairoTextSpan, TextWidth},
    };
    use cairo_lang_macro::TextSpan;

    fn cairo_span(start: u32, end: u32) -> CairoTextSpan {
        CairoTextSpan::new(
            TextWidth::new_for_testing(start).as_offset(),
            TextWidth::new_for_testing(end).as_offset(),
        )
    }

    #[test]
    fn translates_copied_source_start_mappings() {
        let code = "generated copied";
        let copied_mapping = CodeMapping {
            span: cairo_span(10, 16),
            origin: CodeOrigin::Start(TextWidth::new_for_testing(30).as_offset()),
        };

        let translated =
            translate_copied_source_span(&TextSpan::new(10, 16), code, &[copied_mapping]).unwrap();

        assert_eq!(translated.start, 30);
        assert_eq!(translated.end, 36);
    }

    #[test]
    fn ignores_patch_builder_catch_all_span_mapping() {
        let code = "generated";
        let catch_all_mapping = CodeMapping {
            span: cairo_span(0, code.len() as u32),
            origin: CodeOrigin::Span(cairo_span(30, 40)),
        };

        assert!(translate_copied_source_span(
            &TextSpan::new(0, code.len() as u32),
            code,
            &[catch_all_mapping]
        )
        .is_none());
    }

    #[test]
    fn ignores_call_site_mappings() {
        let code = "generated";
        let mapping = CodeMapping {
            span: cairo_span(0, code.len() as u32),
            origin: CodeOrigin::CallSite(cairo_span(30, 40)),
        };

        assert!(translate_copied_source_span(&TextSpan::new(0, 9), code, &[mapping]).is_none());
    }

    #[test]
    fn skips_catch_all_before_precise_copied_source_mapping() {
        let code = "generated copied";
        let catch_all_mapping = CodeMapping {
            span: cairo_span(0, code.len() as u32),
            origin: CodeOrigin::Span(cairo_span(100, 200)),
        };
        let copied_mapping = CodeMapping {
            span: cairo_span(10, 16),
            origin: CodeOrigin::Start(TextWidth::new_for_testing(30).as_offset()),
        };

        let translated = translate_copied_source_span(
            &TextSpan::new(10, 16),
            code,
            &[catch_all_mapping, copied_mapping],
        )
        .unwrap();

        assert_eq!(translated.start, 30);
        assert_eq!(translated.end, 36);
    }
}
