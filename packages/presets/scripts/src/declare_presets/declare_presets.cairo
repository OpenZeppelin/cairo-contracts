use sncast_std::ErrorData;
use sncast_std::ProviderError::{UnknownError};
use sncast_std::StarknetError::{ClassAlreadyDeclared};
use sncast_std::{declare, DeclareResult, get_nonce, DisplayClassHash, FeeSettings, EthFeeSettings};
use sncast_std::{ScriptCommandError, ProviderError, StarknetError};

fn main() {
    let max_fee = 99999999999999999;
    let nonce = get_nonce('latest');

    let account_res = declare(
        "AccountUpgradeable",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    )
        .unwrap_err();
    println!("{:?}", account_res);

    let erc20_res = declare(
        "ERC20Upgradeable",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    )
        .unwrap_err();
    println!("{:?}", erc20_res);

    let erc721_res = declare(
        "ERC721Upgradeable",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    )
        .unwrap_err();
    println!("{:?}", erc721_res);

    let erc1155_res = declare(
        "ERC1155Upgradeable",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    )
        .unwrap_err();
    println!("{:?}", erc1155_res);

    let eth_account_res = declare(
        "EthAccountUpgradeable",
        FeeSettings::Eth(EthFeeSettings { max_fee: Option::Some(max_fee) }),
        Option::Some(nonce)
    )
        .unwrap_err();
    println!("{:?}", eth_account_res);
}
