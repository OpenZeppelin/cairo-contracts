use presets::ERC20Burnable;
use starknet::contract_address_const;

const NAME: felt = 111;
const SYMBOL: felt = 222;

#[test]
#[available_gas(2000000)]
fn initialize() {
    let decimals: u8 = 18_u8;

    ERC20Burnable::mock_constructor(NAME, SYMBOL);

    assert(ERC20Burnable::name() == NAME, 'Name should be NAME');
    assert(ERC20Burnable::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Burnable::decimals() == decimals, 'Decimals should be 18');
}
