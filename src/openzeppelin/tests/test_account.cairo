use openzeppelin::account::Account;
use openzeppelin::account::ACCOUNT_ID;
use openzeppelin::introspection::erc165::IERC165_ID;

const PUB_KEY: felt = 0x123;

#[test]
#[available_gas(2000000)]
fn test_erc165() {
    Account::constructor(PUB_KEY);

    let supports_default_interface: bool = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface: bool = Account::supports_interface(ACCOUNT_ID);
    assert(supports_account_interface, 'Should support account id');

    let public_key: felt = Account::get_public_key();
    assert(public_key == PUB_KEY, 'Should return pub key');
}
