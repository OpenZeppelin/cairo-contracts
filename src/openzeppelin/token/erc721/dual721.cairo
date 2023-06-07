use traits::Into;
use traits::TryInto;
use array::SpanTrait;
use array::ArrayTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use openzeppelin::token::erc721::interface::IERC721;
use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::constants;

struct DualERC721 {
    target: ContractAddress
}

trait DualERC721Trait {
    fn name(self: @DualERC721) -> felt252;
    fn symbol(self: @DualERC721) -> felt252;
    fn token_uri(self: @DualERC721, token_id: u256) -> felt252;
    fn balance_of(self: @DualERC721, account: ContractAddress) -> u256;
    fn owner_of(self: @DualERC721, token_id: u256) -> ContractAddress;
    fn get_approved(self: @DualERC721, token_id: u256) -> ContractAddress;
    fn approve(self: @DualERC721, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(self: @DualERC721, operator: ContractAddress, approved: bool);
    fn transfer_from(self: @DualERC721, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn is_approved_for_all(
        self: @DualERC721, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn safe_transfer_from(
        self: @DualERC721,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
}

impl DualERC721Impl of DualERC721Trait {
    fn name(self: @DualERC721) -> felt252 {
        *call_contract_syscall(*self.target, constants::NAME_SELECTOR, ArrayTrait::new().span())
            .unwrap_syscall()
            .at(0)
    }

    fn symbol(self: @DualERC721) -> felt252 {
        *call_contract_syscall(*self.target, constants::SYMBOL_SELECTOR, ArrayTrait::new().span())
            .unwrap_syscall()
            .at(0)
    }

    fn token_uri(self: @DualERC721, token_id: u256) -> felt252 {
        let snake_selector = constants::TOKEN_URI_SELECTOR;
        let camel_selector = constants::TOKENURI_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        *try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .at(0)
    }

    fn balance_of(self: @DualERC721, account: ContractAddress) -> u256 {
        let snake_selector = constants::BALANCE_OF_SELECTOR;
        let camel_selector = constants::BALANCEOF_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(account.into());

        let res = try_selector_with_fallback(
            *self.target, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();

        u256 { low: (*res.at(0)).try_into().unwrap(), high: (*res.at(1)).try_into().unwrap(),  }
    }

    fn owner_of(self: @DualERC721, token_id: u256) -> ContractAddress {
        let snake_selector = constants::OWNER_OF_SELECTOR;
        let camel_selector = constants::OWNEROF_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        (*try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .at(0))
            .into()
    }

    fn get_approved(self: @DualERC721, token_id: u256) -> ContractAddress {
        let snake_selector = constants::GET_APPROVED_SELECTOR;
        let camel_selector = constants::GETAPPROVED_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        (*try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .at(0))
            .into()
    }

    fn is_approved_for_all(
        self: @DualERC721, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let snake_selector = constants::IS_APPROVED_FOR_ALL_SELECTOR;
        let camel_selector = constants::ISAPPROVEDFORALL_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(owner.into());
        args.append(operator.into());

        (*try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .at(0))
            .into()
    }

    fn approve(self: @DualERC721, to: ContractAddress, token_id: u256) {
        let mut args = ArrayTrait::new();
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());
        call_contract_syscall(*self.target, constants::APPROVE_SELECTOR, args.span());
    }

    fn set_approval_for_all(self: @DualERC721, operator: ContractAddress, approved: bool) {
        let snake_selector = constants::SET_APPROVAL_FOR_ALL_SELECTOR;
        let camel_selector = constants::SETAPPROVALFORALL_SELECTOR;

        let mut args = ArrayTrait::<felt252>::new();
        args.append(operator.into());
        args.append(approved.into());

        try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span())
    }

    fn transfer_from(
        self: @DualERC721, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        let snake_selector = constants::TRANSFER_FROM_SELECTOR;
        let camel_selector = constants::TRANSFERFROM_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(from.into());
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span());
    }

    fn safe_transfer_from(
        self: @DualERC721,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) {
        let snake_selector = constants::SAFE_TRANSFER_FROM_SELECTOR;
        let camel_selector = constants::SAFETRANSFERFROM_SELECTOR;

        let mut args = ArrayTrait::<felt252>::new();
        args.append(from.into());
        args.append(to.into());
        args.append(token_id.low.into());
        args.append(token_id.high.into());

        let len = data.len();
        let mut i = 0;

        loop {
            if i < len {
                args.append(*data.at(i))
            } else {
                break ();
            }
            i = i + 1;
        };

        try_selector_with_fallback(*self.target, snake_selector, camel_selector, args.span());
    }
}
