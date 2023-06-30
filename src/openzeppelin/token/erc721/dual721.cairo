use core::result::ResultTrait;
use traits::Into;
use traits::TryInto;
use array::SpanTrait;
use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use starknet::Felt252TryIntoContractAddress;
use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::BoolIntoFelt252;
use openzeppelin::utils::selectors;

#[derive(Copy, Drop)]
struct DualCaseERC721 {
    contract_address: ContractAddress
}

trait DualCaseERC721Trait {
    fn name(self: @DualCaseERC721) -> felt252;
    fn symbol(self: @DualCaseERC721) -> felt252;
    fn token_uri(self: @DualCaseERC721, token_id: u256) -> felt252;
    fn balance_of(self: @DualCaseERC721, account: ContractAddress) -> u256;
    fn owner_of(self: @DualCaseERC721, token_id: u256) -> ContractAddress;
    fn get_approved(self: @DualCaseERC721, token_id: u256) -> ContractAddress;
    fn approve(self: @DualCaseERC721, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(self: @DualCaseERC721, operator: ContractAddress, approved: bool);
    fn transfer_from(
        self: @DualCaseERC721, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn is_approved_for_all(
        self: @DualCaseERC721, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn safe_transfer_from(
        self: @DualCaseERC721,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
}

impl DualCaseERC721Impl of DualCaseERC721Trait {
    fn name(self: @DualCaseERC721) -> felt252 {
        *call_contract_syscall(*self.contract_address, selectors::name, ArrayTrait::new().span())
            .unwrap_syscall()
            .at(0)
    }

    fn symbol(self: @DualCaseERC721) -> felt252 {
        *call_contract_syscall(*self.contract_address, selectors::symbol, ArrayTrait::new().span())
            .unwrap_syscall()
            .at(0)
    }

    fn token_uri(self: @DualCaseERC721, token_id: u256) -> felt252 {
        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        *try_selector_with_fallback(
            *self.contract_address, selectors::token_uri, selectors::tokenUri, args.span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn balance_of(self: @DualCaseERC721, account: ContractAddress) -> u256 {
        let mut args = ArrayTrait::new();
        args.append(account.into());

        let res = try_selector_with_fallback(
            *self.contract_address, selectors::balance_of, selectors::balanceOf, args.span()
        )
            .unwrap_syscall();

        u256 { low: (*res.at(0)).try_into().unwrap(), high: (*res.at(1)).try_into().unwrap(),  }
    }

    fn owner_of(self: @DualCaseERC721, token_id: u256) -> ContractAddress {
        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        (*try_selector_with_fallback(
            *self.contract_address, selectors::owner_of, selectors::ownerOf, args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn get_approved(self: @DualCaseERC721, token_id: u256) -> ContractAddress {
        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        (*try_selector_with_fallback(
            *self.contract_address, selectors::get_approved, selectors::getApproved, args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn is_approved_for_all(
        self: @DualCaseERC721, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let mut args = ArrayTrait::new();
        args.append(owner.into());
        args.append(operator.into());

        (*try_selector_with_fallback(
            *self.contract_address,
            selectors::is_approved_for_all,
            selectors::isApprovedForAll,
            args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn approve(self: @DualCaseERC721, to: ContractAddress, token_id: u256) {
        let mut args = ArrayTrait::new();
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());
        call_contract_syscall(*self.contract_address, selectors::approve, args.span())
            .unwrap_syscall();
    }

    fn set_approval_for_all(self: @DualCaseERC721, operator: ContractAddress, approved: bool) {
        let mut args = ArrayTrait::new();
        args.append(operator.into());
        args.append(approved.into());

        try_selector_with_fallback(
            *self.contract_address,
            selectors::set_approval_for_all,
            selectors::setApprovalForAll,
            args.span()
        )
            .unwrap_syscall();
    }

    fn transfer_from(
        self: @DualCaseERC721, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        let mut args = ArrayTrait::new();
        args.append(from.into());
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        try_selector_with_fallback(
            *self.contract_address, selectors::transfer_from, selectors::transferFrom, args.span()
        )
            .unwrap_syscall();
    }

    fn safe_transfer_from(
        self: @DualCaseERC721,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        mut data: Span<felt252>
    ) {
        let mut args = ArrayTrait::new();
        args.append(from.into());
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());
        args.append(data.len().into());

        loop {
            match data.pop_front() {
                Option::Some(x) => args.append(*x),
                Option::None(_) => {
                    break ();
                }
            };
        };

        try_selector_with_fallback(
            *self.contract_address,
            selectors::safe_transfer_from,
            selectors::safeTransferFrom,
            args.span()
        )
            .unwrap_syscall();
    }
}
