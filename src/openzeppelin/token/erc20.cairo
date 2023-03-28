use starknet::ContractAddress;

trait IERC20 {
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> u8;
    fn total_supply() -> u256;
    fn balance_of(account: ContractAddress) -> u256;
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}

#[contract]
mod ERC20 {
    use openzeppelin::token::erc20::IERC20;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::ContractAddressZeroable;
    use zeroable::Zeroable;

    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, value: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, spender: ContractAddress, value: u256) {}

    impl ERC20 of IERC20 {
        fn name() -> felt252 {
            _name::read()
        }

        fn symbol() -> felt252 {
            _symbol::read()
        }

        fn decimals() -> u8 {
            18_u8
        }

        fn total_supply() -> u256 {
            _total_supply::read()
        }

        fn balance_of(account: ContractAddress) -> u256 {
            _balances::read(account)
        }

        fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
            _allowances::read((owner, spender))
        }

        fn transfer(recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            _transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            _spend_allowance(sender, caller, amount);
            _transfer(sender, recipient, amount);
            true
        }

        fn approve(spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            _approve(caller, spender, amount);
            true
        }
    }

    #[constructor]
    fn constructor(
        name: felt252, symbol: felt252, initial_supply: u256, recipient: ContractAddress
    ) {
        initializer(name, symbol);
        _mint(recipient, initial_supply);
    }

    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    #[view]
    fn total_supply() -> u256 {
        ERC20::total_supply()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC20::balance_of(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount)
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount)
    }

    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        _increase_allowance(spender, added_value)
    }

    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        _decrease_allowance(spender, subtracted_value)
    }

    ///
    /// Internals
    ///

    fn initializer(name_: felt252, symbol_: felt252) {
        _name::write(name_);
        _symbol::write(symbol_);
    }

    fn _increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) + added_value);
        true
    }

    fn _decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) - subtracted_value);
        true
    }

    fn _mint(recipient: ContractAddress, amount: u256) {
        assert(!recipient.is_zero(), 'ERC20: mint to 0');
        _total_supply::write(_total_supply::read() + amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(contract_address_const::<0>(), recipient, amount);
    }

    fn _burn(account: ContractAddress, amount: u256) {
        assert(!account.is_zero(), 'ERC20: burn from 0');
        _total_supply::write(_total_supply::read() - amount);
        _balances::write(account, _balances::read(account) - amount);
        Transfer(account, contract_address_const::<0>(), amount);
    }

    fn _approve(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        assert(!owner.is_zero(), 'ERC20: approve from 0');
        assert(!spender.is_zero(), 'ERC20: approve to 0');
        _allowances::write((owner, spender), amount);
        Approval(owner, spender, amount);
    }

    fn _transfer(sender: ContractAddress, recipient: ContractAddress, amount: u256) {
        assert(!sender.is_zero(), 'ERC20: transfer from 0');
        assert(!recipient.is_zero(), 'ERC20: transfer to 0');
        _balances::write(sender, _balances::read(sender) - amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(sender, recipient, amount);
    }

    fn _spend_allowance(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        let current_allowance = _allowances::read((owner, spender));
        let ONES_MASK = 0xffffffffffffffffffffffffffffffff_u128;
        let is_unlimited_allowance =
            current_allowance.low == ONES_MASK & current_allowance.high == ONES_MASK;
        if !is_unlimited_allowance {
            _approve(owner, spender, current_allowance - amount);
        }
    }
}
