#[contract]
mod ERC20Library {
    use starknet::get_caller_address;

    struct Storage {
        _name: felt,
        _symbol: felt,
        _total_supply: u256,
        _balances: LegacyMap::<felt, u256>,
        _allowances: LegacyMap::<(felt, felt), u256>,
    }

    #[event]
    fn Transfer(from_: felt, to: felt, value: u256) {}

    #[event]
    fn Approval(owner: felt, spender: felt, value: u256) {}

    fn initializer(
        name: felt, symbol: felt, initial_supply: u256, recipient: felt
    ) {
        _name::write(name);
        _symbol::write(symbol);
        _mint(recipient, initial_supply);
    }

    fn name() -> felt {
        _name::read()
    }

    fn symbol() -> felt {
        _symbol::read()
    }

    fn decimals() -> u8 {
        u8_from_felt(18)
    }

    fn total_supply() -> u256 {
        _total_supply::read()
    }

    fn balance_of(account: felt) -> u256 {
        _balances::read(account)
    }

    fn allowance(owner: felt, spender: felt) -> u256 {
        _allowances::read((owner, spender))
    }

    fn transfer(recipient: felt, amount: u256) {
        let sender = get_caller_address();
        _transfer(sender, recipient, amount);
    }

    fn transfer_from(sender: felt, recipient: felt, amount: u256) {
        let caller = get_caller_address();
        _spend_allowance(sender, caller, amount);
        _transfer(sender, recipient, amount);
    }

    fn approve(spender: felt, amount: u256) {
        let caller = get_caller_address();
        _approve(caller, spender, amount);
    }

    fn increase_allowance(spender: felt, added_value: u256) {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) + added_value);
    }

    fn decrease_allowance(spender: felt, subtracted_value: u256) {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) - subtracted_value);
    }

    fn _transfer(sender: felt, recipient: felt, amount: u256) {
        assert(sender != 0, 'ERC20: transfer from 0');
        assert(recipient != 0, 'ERC20: transfer to 0');
        _balances::write(sender, _balances::read(sender) - amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(sender, recipient, amount);
    }

    fn _mint(recipient: felt, amount: u256) {
        assert(recipient != 0, 'ERC20: mint to the 0 address');
        _total_supply::write(_total_supply::read() + amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(0, recipient, amount);
    }

    fn _burn(account: felt, amount: u256) {
        assert(account != 0, 'ERC20: burn from 0');
        _total_supply::write(_total_supply::read() - amount);
        _balances::write(account, _balances::read(account) - amount);
        Transfer(account, 0, amount);
    }

    fn _approve(owner: felt, spender: felt, amount: u256) {
        assert(spender != 0, 'ERC20: approve from 0');
        _allowances::write((owner, spender), amount);
        Approval(owner, spender, amount);
    }

    fn _spend_allowance(owner: felt, spender: felt, amount: u256) {
        let current_allowance = _allowances::read((owner, spender));
        let ONES_MASK = 0xffffffffffffffffffffffffffffffff_u128;
        let is_unlimited_allowance =
            current_allowance.low == ONES_MASK & current_allowance.high == ONES_MASK;
        if !is_unlimited_allowance {
            assert(current_allowance >= amount, 'ERC20: insufficient allowance');
            _approve(owner, spender, current_allowance - amount);
        }
    }
}
