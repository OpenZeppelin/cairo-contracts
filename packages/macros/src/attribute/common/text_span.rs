use std::collections::{HashMap, VecDeque};

use cairo_lang_macro::{quote, TextSpan, Token, TokenStream, TokenTree};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::with_db::SyntaxNodeWithDb;

fn make_ident(text: &str, span: TextSpan) -> TokenTree {
    TokenTree::Ident(Token::new(text, span))
}

fn tokenize_str(s: &str, db: &SimpleParserDatabase) -> TokenStream {
    // Unwrap is safe as long as s is a valid cairo code
    let syntax_node = db.parse_virtual(s).unwrap();
    let syntax_node_with_db = SyntaxNodeWithDb::new(&syntax_node, db);
    quote! {#syntax_node_with_db}
}

/// Merge spans from `initial_tokens` into a tokenized version of `final_output`.
/// - If a token text in `final_output` matches one from `initial_tokens` (by exact text),
///   it inherits that token’s span (first-come, first-served).
/// - Otherwise, it gets `TextSpan::call_site()`.
pub fn merge_spans_from_initial(
    initial_tokens: &[TokenTree],
    final_output: &str,
    db: &SimpleParserDatabase,
) -> Vec<TokenTree> {
    // Build a multimap: text -> queue of spans (to support duplicates, left-to-right)
    let mut span_index: HashMap<String, VecDeque<TextSpan>> = HashMap::new();
    for tt in initial_tokens {
        let TokenTree::Ident(tok) = tt;
        let text = tok.content.to_string();
        span_index
            .entry(text)
            .or_default()
            .push_back(tok.span.clone());
    }

    // Tokenize final output
    let final_tokens = tokenize_str(final_output, db)
        .tokens
        .iter()
        .map(|tt| {
            let TokenTree::Ident(tok) = tt;
            tok.content.to_string()
        })
        .collect::<Vec<_>>();

    // Rebuild final tokens, reusing spans when the text matches; else call_site.
    let mut out = Vec::with_capacity(final_tokens.len());
    for text in final_tokens {
        if let Some(queue) = span_index.get_mut(&text) {
            if let Some(span) = queue.pop_front() {
                out.push(make_ident(&text, span));
                if queue.is_empty() {
                    // keep the map clean
                    span_index.remove(&text);
                }
                continue;
            }
        }
        out.push(make_ident(&text, TextSpan::call_site()));
    }

    out
}
