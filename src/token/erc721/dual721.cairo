// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc721/dual721.cairo)

use array::ArrayTrait;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;

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
    fn supports_interface(self: @DualCaseERC721, interface_id: felt252) -> bool;
}

impl DualCaseERC721Impl of DualCaseERC721Trait {
    fn name(self: @DualCaseERC721) -> felt252 {
        call_contract_syscall(*self.contract_address, selectors::name, array![].span())
            .unwrap_and_cast()
    }

    fn symbol(self: @DualCaseERC721) -> felt252 {
        call_contract_syscall(*self.contract_address, selectors::symbol, array![].span())
            .unwrap_and_cast()
    }

    fn token_uri(self: @DualCaseERC721, token_id: u256) -> felt252 {
        let mut args = array![];
        args.append_serde(token_id);

        try_selector_with_fallback(
            *self.contract_address, selectors::token_uri, selectors::tokenUri, args.span()
        )
            .unwrap_and_cast()
    }

    fn balance_of(self: @DualCaseERC721, account: ContractAddress) -> u256 {
        let mut args = array![];
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::balance_of, selectors::balanceOf, args.span()
        )
            .unwrap_and_cast()
    }

    fn owner_of(self: @DualCaseERC721, token_id: u256) -> ContractAddress {
        let mut args = array![];
        args.append_serde(token_id);

        try_selector_with_fallback(
            *self.contract_address, selectors::owner_of, selectors::ownerOf, args.span()
        )
            .unwrap_and_cast()
    }

    fn get_approved(self: @DualCaseERC721, token_id: u256) -> ContractAddress {
        let mut args = array![];
        args.append_serde(token_id);

        try_selector_with_fallback(
            *self.contract_address, selectors::get_approved, selectors::getApproved, args.span()
        )
            .unwrap_and_cast()
    }

    fn is_approved_for_all(
        self: @DualCaseERC721, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(operator);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::is_approved_for_all,
            selectors::isApprovedForAll,
            args.span()
        )
            .unwrap_and_cast()
    }

    fn approve(self: @DualCaseERC721, to: ContractAddress, token_id: u256) {
        let mut args = array![];
        args.append_serde(to);
        args.append_serde(token_id);
        call_contract_syscall(*self.contract_address, selectors::approve, args.span())
            .unwrap_syscall();
    }

    fn set_approval_for_all(self: @DualCaseERC721, operator: ContractAddress, approved: bool) {
        let mut args = array![];
        args.append_serde(operator);
        args.append_serde(approved);

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
        let mut args = array![];
        args.append_serde(from);
        args.append_serde(to);
        args.append_serde(token_id);

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
        let mut args = array![];
        args.append_serde(from);
        args.append_serde(to);
        args.append_serde(token_id);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::safe_transfer_from,
            selectors::safeTransferFrom,
            args.span()
        )
            .unwrap_syscall();
    }

    fn supports_interface(self: @DualCaseERC721, interface_id: felt252) -> bool {
        let mut args = array![];
        args.append_serde(interface_id);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::supports_interface,
            selectors::supportsInterface,
            args.span()
        )
            .unwrap_and_cast()
    }
}
