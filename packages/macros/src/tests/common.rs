use cairo_lang_formatter::format_string;
use cairo_lang_macro::ProcMacroResult;
use cairo_lang_parser::utils::SimpleParserDatabase;
use indoc::formatdoc;

pub(crate) fn format_proc_macro_result(raw_result: ProcMacroResult) -> String {
    let none = "None";

    let mut token_stream = raw_result.token_stream.to_string();
    if token_stream.is_empty() {
        token_stream = none.to_string();
    } else {
        let db = SimpleParserDatabase::default();
        let formatted_token_stream = format_string(&db, token_stream);
        token_stream = formatted_token_stream;
    }

    let mut diagnostics = String::new();
    for d in raw_result.diagnostics {
        diagnostics += format!("====\n{:?}: {}====", d.severity(), d.message()).as_str();
    }
    if diagnostics.is_empty() {
        diagnostics = none.to_string();
    }

    formatdoc! {
        "
        TokenStream:

        {}

        Diagnostics:

        {}

        AuxData:

        {:?}
        ",
        token_stream, diagnostics, raw_result.aux_data
    }
}
