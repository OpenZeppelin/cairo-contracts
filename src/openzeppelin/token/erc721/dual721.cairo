use starknet::call_contract_syscall;
use openzeppelin::token::erc721::interface::IERC721;
use openzeppelin::utils::try_selector_with_fallback;

impl DualERC721Impl of IERC721 {
    fn name(target: ContractAddress) -> felt252 {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        try_selector_with_fallback(target, snake_selector, camel_selector, ArrayTrait::new().span())
            .unwrap_syscall()
            .into()
    }

    fn symbol(target: ContractAddress) -> felt252 {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        try_selector_with_fallback(target, snake_selector, camel_selector, ArrayTrait::new().span())
            .unwrap_syscall()
            .into()
    }

    fn token_uri(target: ContractAddress, token_id: u256) -> felt252 {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(token_id);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .into()
    }

    fn balance_of(target: ContractAddress, account: ContractAddress) -> u256 {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(account);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .into()
    }

    fn owner_of(target: ContractAddress, token_id: u256) -> ContractAddress {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(token_id);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .into()
    }

    fn get_approved(target: ContractAddress, token_id: u256) -> ContractAddress {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(token_id);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .into()
    }

    fn is_approved_for_all(
        target: ContractAddress, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(owner);
        args.append(operator);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
            .unwrap_syscall()
            .into()
    }

    fn approve(target: ContractAddress, to: ContractAddress, token_id: u256) {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(to);
        args.append(token_id);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
    }

    fn set_approval_for_all(target: ContractAddress, operator: ContractAddress, approved: bool) {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(operator);
        args.append(approved);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
    }

    fn transfer_from(
        target: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(from);
        args.append(to);
        args.append(token_id);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
    }

    fn safe_transfer_from(
        target: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) {
        let snake_selector = 0x123;
        let camel_selector = 0x123;

        let args = ArrayTrait::new();
        args.append(from);
        args.append(to);
        args.append(token_id);
        args.append(data);

        try_selector_with_fallback(target, snake_selector, camel_selector, args.span())
    }
}
