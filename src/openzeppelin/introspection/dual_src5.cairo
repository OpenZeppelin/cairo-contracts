use array::ArrayTrait;
use starknet::ContractAddress;

use openzeppelin::utils::selectors;
use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::UnwrapAndCast;

#[derive(Copy, Drop)]
struct DualCaseSRC5 {
    contract_address: ContractAddress
}

trait DualCaseSRC5Trait {
    fn supports_interface(self: @DualCaseSRC5, interface_id: felt252) -> bool;
}

impl DualCaseSRC5Impl of DualCaseSRC5Trait {
    fn supports_interface(self: @DualCaseSRC5, interface_id: felt252) -> bool {
        let mut args = array![interface_id];

        try_selector_with_fallback(
            *self.contract_address,
            selectors::supports_interface,
            selectors::supportsInterface,
            args.span()
        )
            .unwrap_and_cast()
    }
}
