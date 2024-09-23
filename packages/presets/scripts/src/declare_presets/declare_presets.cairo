use openzeppelin_testing::common::IntoBase16String;
use sncast_std::{declare, get_nonce, FeeSettings, EthFeeSettings};

const max_fee: felt252 = 99999999999999999;

fn main() {
    let contracts: Array<ByteArray> = array![
        "AccountUpgradeable",
        "ERC20Upgradeable",
        "ERC721Upgradeable",
        "ERC1155Upgradeable",
        "EthAccountUpgradeable"
    ];

    let mut consume_latest_nonce = false;
    let mut nonce = get_nonce('latest');

    for contract in contracts {
        if (!consume_latest_nonce) {
            consume_latest_nonce = true;
        } else {
            nonce = get_nonce('pending');
        }

        declare_preset(contract, nonce);
    };

    println!("");
}

fn declare_preset(contract: ByteArray, nonce: felt252) {
    println!("\nDeclaring {contract}:");

    let declare_result = declare(
        contract,
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    );

    // Print output
    // Note that the tx hash will already display from the declaration
    match declare_result {
        Result::Ok(r) => println!("Class hash = {}", r.class_hash.into_base_16_string()),
        Result::Err(r) => println!("{:?}", r)
    }
}
