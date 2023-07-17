#[contract]
mod NonERC721 {
    #[view]
    fn nope() -> bool {
        false
    }
}
