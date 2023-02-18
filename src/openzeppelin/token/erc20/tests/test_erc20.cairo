use presets::ERC20;
use starknet::contract_address_const;
use integer::u256_from_felt;

const NAME: felt = 111;
const SYMBOL: felt = 222;

#[test]
#[available_gas(2000000)]
fn initialize() {
    let decimals: u8 = 18_u8;

    ERC20::mock_constructor(NAME, SYMBOL);

    assert(ERC20::name() == NAME, 'Name should be NAME');
    assert(ERC20::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20::decimals() == decimals, 'Decimals should be 18');
}
