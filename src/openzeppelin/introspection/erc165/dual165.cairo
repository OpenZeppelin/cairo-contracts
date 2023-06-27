use array::SpanTrait;
use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use traits::Into;
use traits::TryInto;

use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::constants;

#[derive(Copy, Drop)]
struct DualCaseERC165 {
    contract_address: ContractAddress
}

trait DualCaseERC165Trait {
    fn supports_interface(self: @DualCaseERC165, interface_id: u32) -> bool;
}

impl DualCaseERC165Impl of DualCaseERC165Trait {
    fn supports_interface(self: @DualCaseERC165, interface_id: u32) -> bool {
        let snake_selector = constants::supports_interface_SELECTOR;
        let camel_selector = constants::supportsInterface_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(interface_id.into());

        (*try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }
}
