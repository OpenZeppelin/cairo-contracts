#[contract]
mod NonImplementingMock {
    #[view]
    fn nope() -> bool {
        false
    }
}
