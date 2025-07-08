/// Creates and returns a new array consisting of the given `element` repeated `n_times` times.
pub fn repeat<T, N, +Copy<T>, +Drop<T>, +Into<N, u256>>(element: T, n_times: N) -> Array<T> {
    let mut result = array![];
    let len: u256 = n_times.into();
    for _ in 0..len {
        result.append(element);
    }
    result
}
