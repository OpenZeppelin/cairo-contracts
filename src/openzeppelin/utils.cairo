use array::ArrayTrait;
use array::SpanTrait;
use box::BoxTrait;
use option::OptionTrait;
mod constants;

#[inline(always)]
fn check_gas() {
    match gas::withdraw_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('Out of gas');
            panic(data);
        },
    }
}

fn span_to_array<T, impl TDrop: Drop<T>, impl TCopy: Copy<T>>(span: Span<T>) -> Array<T> {
    let mut array = ArrayTrait::<T>::new();
    let length = span.len();
    let mut i = 0;

    loop {
        if i == length {
            break ();
        }
        array.append(*span.get(1).unwrap().unbox());
        check_gas();
        i += 1;
    };
    array
}
