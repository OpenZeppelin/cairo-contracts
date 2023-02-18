use presets::ERC20Mintable;
use starknet::contract_address_const;
use integer::u256_from_felt;

const NAME: felt = 111;
const SYMBOL: felt = 222;

#[test]
#[available_gas(2000000)]
fn initialize() {
    let decimals: u8 = 18_u8;

    ERC20Mintable::mock_constructor(NAME, SYMBOL);

    assert(ERC20Mintable::name() == NAME, 'Name should be NAME');
    assert(ERC20Mintable::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Mintable::decimals() == decimals, 'Decimals should be 18');
}
