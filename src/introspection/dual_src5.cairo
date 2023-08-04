// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (introspection/dual_src5.cairo)

use array::ArrayTrait;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;

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
