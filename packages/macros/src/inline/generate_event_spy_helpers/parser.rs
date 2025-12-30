use nom::{
    branch::alt,
    bytes::complete::tag,
    character::complete::{alpha1, alphanumeric1, char, multispace0, multispace1},
    combinator::{map, opt},
    error::{ErrorKind, ParseError},
    multi::{many0, separated_list0},
    sequence::{delimited, pair},
    Parser,
};

type ParseResult<'a, T> = nom::IResult<&'a str, T, ParserError>;

#[derive(Debug)]
pub struct ImplBlock {
    pub is_public: bool,
    pub name: String,
    pub events: Vec<Event>,
}

#[derive(Debug)]
pub struct Event {
    pub name: String,
    pub fields: Vec<Parameter>,
    pub is_only: bool,
}

#[derive(Debug)]
pub struct Parameter {
    pub is_key: bool,
    pub name: String,
    pub ty: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParserError {
    message: String,
}

impl ParserError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }

    fn with_context(message: impl Into<String>, tip: &'static str, input: &str) -> Self {
        let mut full = message.into();
        if !tip.is_empty() {
            full.push(' ');
            full.push_str(tip);
        }
        if !input.trim_start().is_empty() {
            full.push_str(&format!(" (around `{}`)", preview(input)));
        } else {
            full.push_str(" (near end of input)");
        }
        Self { message: full }
    }
}

impl std::fmt::Display for ParserError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for ParserError {}

impl<'a> ParseError<&'a str> for ParserError {
    fn from_error_kind(input: &'a str, kind: ErrorKind) -> Self {
        ParserError::with_context(
            format!("Unexpected syntax ({:?}).", kind),
            "Expected syntax like `{ impl Helper { event Foo(...); } }`.",
            input,
        )
    }

    fn append(input: &'a str, kind: ErrorKind, mut other: Self) -> Self {
        other.message.push_str(&format!(
            " Additional context: {:?} near `{}`.",
            kind,
            preview(input)
        ));
        other
    }
}

// Parses an identifier like `AccessControlDefaultAdminRulesSpyHelpers`
fn identifier(input: &str) -> ParseResult<String> {
    map(
        pair(alpha1, many0(alt((alphanumeric1, tag("_"))))),
        |(first, rest)| format!("{}{}", first, rest.concat()),
    )
    .parse(input)
}

// #[key] (optional)
fn key_attribute(input: &str) -> ParseResult<bool> {
    let (input, attr) = opt(|input| {
        let (input, _) = tag("#[")(input)?;
        let (input, attr) = identifier(input)?;
        let (input, _) = expect_char_token(
            input,
            ']',
            "close the attribute",
            "Attributes must end with `]`.",
        )?;
        Ok((input, attr))
    })
    .parse(input)?;

    if let Some(attr) = attr {
        if attr != "key" {
            return Err(nom::Err::Failure(ParserError::new(format!(
                "Unsupported parameter attribute `#[{}]`. Tip: only `#[key]` is allowed on event fields.",
                attr
            ))));
        }
        Ok((input, true))
    } else {
        Ok((input, false))
    }
}

// new_admin: ContractAddress
fn parameter(input: &str) -> ParseResult<Parameter> {
    map(
        (
            multispace0,
            key_attribute,
            multispace0,
            identifier,
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    ':',
                    "separate the field name from its type",
                    "Use `name: Type` for parameters.",
                )
            },
            multispace0,
            identifier,
            multispace0,
        ),
        |(_, is_key, _, name, _, _, _, ty, _)| Parameter { is_key, name, ty },
    )
    .parse(input)
}

// event DefaultAdminTransferScheduled(...)
fn event(input: &str) -> ParseResult<Event> {
    let (input, _) = multispace0(input)?;
    let (input, is_only) = event_attributes(input)?;
    let (input, _) = multispace0(input)?;

    if input.is_empty() || input.starts_with('}') {
        return Err(nom::Err::Error(ParserError::new(
            "No more events present in the impl block.",
        )));
    }

    let (input, _) = expect_token(
        input,
        "event",
        "start an event definition",
        "Use `event Name(...)` inside the impl body.",
    )?;
    let (input, _) = multispace1(input)?;
    let (input, name) = identifier(input)?;
    let (input, fields) = delimited(
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    '(',
                    "open the parameter list",
                    "Add `(` right after the event name.",
                )
            },
            multispace0,
        ),
        separated_list0(char(','), parameter),
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    ')',
                    "close the parameter list",
                    "Balance `(` and `)` around the parameters.",
                )
            },
            multispace0,
        ),
    )
    .parse(input)?;
    let (input, _) = expect_char_token(
        input,
        ';',
        "finish the event definition",
        "Terminate each event with `;`.",
    )?;
    Ok((
        input,
        Event {
            name,
            fields,
            is_only,
        },
    ))
}

fn event_attributes(input: &str) -> ParseResult<bool> {
    let (input, _) = multispace0(input)?;

    // Parse #[...] if present
    let (input, maybe_attrs): (&str, Option<Vec<&str>>) = opt(|input| {
        delimited(
            tag("#["),
            separated_list0(delimited(multispace0, char(','), multispace0), alpha1),
            |i| {
                expect_char_token(
                    i,
                    ']',
                    "close the attribute list",
                    "Attributes must end with `]`.",
                )
            },
        )
        .parse(input)
    })
    .parse(input)?;

    let attrs = maybe_attrs.unwrap_or_default();

    for attr in &attrs {
        if *attr != "only" {
            return Err(nom::Err::Failure(ParserError::new(format!(
                "Unsupported event attribute `#[{}]`. Tip: only `#[only]` is allowed before events.",
                attr
            ))));
        }
    }

    let is_only = attrs.contains(&"only");
    Ok((input, is_only))
}

// impl AccessControlDefaultAdminRulesSpyHelpers { ... }
fn impl_block(input: &str) -> ParseResult<ImplBlock> {
    let (input, _) = multispace0(input)?;
    let (input, is_public) = opt(tag("pub")).parse(input)?;
    let (input, _) = multispace0(input)?;
    let (input, _) = expect_token(
        input,
        "impl",
        "begin the helper implementation",
        "Start with `impl Name { ... }` (optionally prefix with `pub`).",
    )?;
    let (input, _) = multispace1(input)?;
    let (input, name) = identifier(input)?;
    let (input, events) = delimited(
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    '{',
                    "open the helper body",
                    "Wrap event definitions inside `{ ... }`.",
                )
            },
            multispace0,
        ),
        many0(event),
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    '}',
                    "close the helper body",
                    "Ensure there is a matching `}` after your events.",
                )
            },
            multispace0,
        ),
    )
    .parse(input)?;
    let is_public = is_public.is_some();
    Ok((
        input,
        ImplBlock {
            is_public,
            name,
            events,
        },
    ))
}

// Outer {}
pub fn parse_dsl(input: &str) -> ParseResult<ImplBlock> {
    delimited(
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    '{',
                    "wrap the macro input",
                    "Invoke the macro with `{ impl Name { ... } }`.",
                )
            },
            multispace0,
        ),
        impl_block,
        delimited(
            multispace0,
            |i| {
                expect_char_token(
                    i,
                    '}',
                    "close the macro input",
                    "Add a trailing `}` after the impl block.",
                )
            },
            multispace0,
        ),
    )
    .parse(input)
}

fn expect_token<'a>(
    input: &'a str,
    token: &'static str,
    purpose: &'static str,
    tip: &'static str,
) -> ParseResult<'a, &'a str> {
    match tag::<&str, &str, ParserError>(token)(input) {
        Ok(res) => Ok(res),
        Err(_) => Err(nom::Err::Failure(ParserError::with_context(
            format!("Expected `{}` to {}.", token, purpose),
            tip,
            input,
        ))),
    }
}

fn expect_char_token<'a>(
    input: &'a str,
    ch: char,
    purpose: &'static str,
    tip: &'static str,
) -> ParseResult<'a, char> {
    match char::<&str, ParserError>(ch)(input) {
        Ok(res) => Ok(res),
        Err(_) => Err(nom::Err::Failure(ParserError::with_context(
            format!("Expected `{}` to {}.", ch, purpose),
            tip,
            input,
        ))),
    }
}

fn preview(input: &str) -> String {
    let trimmed = input.trim_start();
    if trimmed.is_empty() {
        return "EOF".to_string();
    }
    let mut snippet: String = trimmed.chars().take(18).collect();
    if trimmed.chars().count() > 18 {
        snippet.push_str("...");
    }
    snippet
}
