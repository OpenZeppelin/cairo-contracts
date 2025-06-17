pub trait ERC6372Clock {
    /// Returns the current clock value used for time-dependent operations.
    ///
    /// Requirements:
    ///
    /// - This function MUST always be non-decreasing.
    fn clock() -> u64;

    /// Returns a description of the clock's mode or time measurement mechanism.
    ///
    /// Requirements:
    ///
    /// - The output MUST be formatted like a URL query string, decodable in standard JavaScript.
    fn CLOCK_MODE() -> ByteArray;
}
