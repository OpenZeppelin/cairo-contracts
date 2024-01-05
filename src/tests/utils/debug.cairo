use core::fmt::{Debug, Formatter, Error};
use starknet::{ContractAddress, ClassHash};

impl DebugContractAddress of core::fmt::Debug<ContractAddress> {
    fn fmt(self: @ContractAddress, ref f: Formatter) -> Result<(), Error> {
        let address: felt252 = (*self).into();
        write!(f, "{address:?}")
    }
}

impl DebugClassHash of core::fmt::Debug<ClassHash> {
    fn fmt(self: @ClassHash, ref f: Formatter) -> Result<(), Error> {
        let hash: felt252 = (*self).into();
        write!(f, "{hash:?}")
    }
}
