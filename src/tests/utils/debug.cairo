use core::fmt::{Debug, Formatter, Error};
use starknet::{ContractAddress, ClassHash};

impl DebugClassHash of core::fmt::Debug<ClassHash> {
    fn fmt(self: @ClassHash, ref f: Formatter) -> Result<(), Error> {
        let hash: felt252 = (*self).into();
        write!(f, "{hash:?}")
    }
}
