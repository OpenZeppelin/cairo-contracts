pub trait IERC6372Clock {
    /// Returns the current clock value used for time-dependent operations.
    fn clock() -> u64;

    /// Returns a parsable description of the clock's mode or time measurement mechanism.
    ///
    /// CAUTION: This function MUST always be non-decreasing.
    fn CLOCK_MODE() -> ByteArray;
}
