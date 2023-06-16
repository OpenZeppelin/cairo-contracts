#[contract]
mod NonERC721Mock {
    #[view]
    fn nope() -> bool {
        false
    }
}
