use core::fmt::{Debug, Formatter, Error};
use starknet::ContractAddress;

impl DebugContractAddress of core::fmt::Debug<ContractAddress> {
    fn fmt(self: @ContractAddress, ref f: Formatter) -> Result<(), Error> {
        let address: felt252 = (*self).into();
        write!(f, "{address:?}")
    }
}
