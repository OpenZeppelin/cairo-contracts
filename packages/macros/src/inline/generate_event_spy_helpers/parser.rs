use nom::{
    branch::alt,
    bytes::complete::tag,
    character::complete::{alpha1, alphanumeric1, char, multispace0, multispace1},
    combinator::{map, opt},
    multi::{many0, separated_list0},
    sequence::{delimited, pair},
    IResult, Parser,
};

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

// Parses an identifier like `AccessControlDefaultAdminRulesSpyHelpers`
fn identifier(input: &str) -> IResult<&str, String> {
    map(
        pair(alpha1, many0(alt((alphanumeric1, tag("_"))))),
        |(first, rest)| format!("{}{}", first, rest.concat()),
    )
    .parse(input)
}

// #[key] (optional)
fn key_attribute(input: &str) -> IResult<&str, bool> {
    map(opt(delimited(tag("#["), tag("key"), tag("]"))), |opt_key| {
        opt_key.is_some()
    })
    .parse(input)
}

// new_admin: ContractAddress
fn parameter(input: &str) -> IResult<&str, Parameter> {
    map(
        (
            multispace0,
            key_attribute,
            multispace0,
            identifier,
            multispace0,
            char(':'),
            multispace0,
            identifier,
            multispace0,
        ),
        |(_, is_key, _, name, _, _, _, ty, _)| Parameter { is_key, name, ty },
    )
    .parse(input)
}

// event DefaultAdminTransferScheduled(...)
fn event(input: &str) -> IResult<&str, Event> {
    let (input, _) = multispace0(input)?;
    let (input, is_only) = event_attributes(input)?;
    let (input, _) = multispace0(input)?;
    let (input, _) = tag("event")(input)?;
    let (input, _) = multispace1(input)?;
    let (input, name) = identifier(input)?;
    let (input, fields) = delimited(
        delimited(multispace0, char('('), multispace0),
        separated_list0(char(','), parameter),
        delimited(multispace0, char(')'), multispace0),
    )
    .parse(input)?;
    let (input, _) = char(';').parse(input)?;
    Ok((
        input,
        Event {
            name,
            fields,
            is_only,
        },
    ))
}

fn event_attributes(input: &str) -> IResult<&str, bool> {
    let (input, _) = multispace0(input)?;

    // Parse #[...] if present
    let (input, maybe_attrs): (&str, Option<Vec<&str>>) = opt(delimited(
        tag("#["),
        separated_list0(delimited(multispace0, char(','), multispace0), alpha1),
        tag("]"),
    ))
    .parse(input)?;

    let attrs = maybe_attrs.unwrap_or_default();

    for attr in &attrs {
        if *attr != "only" {
            return Err(nom::Err::Failure(nom::error::Error::new(
                input,
                nom::error::ErrorKind::Verify,
            )));
        }
    }

    let is_only = attrs.contains(&"only");
    Ok((input, is_only))
}

// impl AccessControlDefaultAdminRulesSpyHelpers { ... }
fn impl_block(input: &str) -> IResult<&str, ImplBlock> {
    let (input, _) = multispace0(input)?;
    let (input, is_public) = opt(tag("pub")).parse(input)?;
    let (input, _) = multispace0(input)?;
    let (input, _) = tag("impl")(input)?;
    let (input, _) = multispace1(input)?;
    let (input, name) = identifier(input)?;
    let (input, events) = delimited(
        delimited(multispace0, char('{'), multispace0),
        many0(event),
        delimited(multispace0, char('}'), multispace0),
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
pub fn parse_dsl(input: &str) -> IResult<&str, ImplBlock> {
    delimited(
        delimited(multispace0, char('{'), multispace0),
        impl_block,
        delimited(multispace0, char('}'), multispace0),
    )
    .parse(input)
}
