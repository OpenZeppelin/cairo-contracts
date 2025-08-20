use crate::attribute::with_components::definition::with_components_avevetedp5blk as with_components;
use cairo_lang_macro::{quote, TokenStream};
use insta::assert_snapshot;

use super::common::format_proc_macro_result;

#[test]
fn test_with_account() {
    let attribute = quote! { (Account) };
    let item = quote! {
        #[starknet::contract(account)]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, public_key: felt252) {
                self.account.initializer(public_key);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_account_no_initializer() {
    let attribute = quote! { (Account) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_eth_account() {
    let attribute = quote! { (EthAccount) };
    let item = quote! {
        #[starknet::contract(account)]
        pub mod MyContract {
            use openzeppelin_interfaces::accounts::EthPublicKey;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, public_key: EthPublicKey) {
                self.eth_account.initializer(public_key);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_eth_account_no_initializer() {
    let attribute = quote! { (EthAccount) };
    let item = quote! {
        #[starknet::contract(account)]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_src9() {
    let attribute = quote! { (SRC9) };
    let item = quote! {
        #[starknet::contract(src9)]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.src9.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_src9_no_initializer() {
    let attribute = quote! { (SRC9) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc20() {
    let attribute = quote! { (ERC20) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::{ERC20HooksEmptyImpl, DefaultConfig};
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc20.initializer("MyToken", "MTK");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc20_no_initializer() {
    let attribute = quote! { (ERC20) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::{ERC20HooksEmptyImpl, DefaultConfig};
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc20_no_hooks_impl() {
    let attribute = quote! { (ERC20) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::DefaultConfig;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc20.initializer("MyToken", "MTK");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc20_no_config() {
    let attribute = quote! { (ERC20) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc20.initializer("MyToken", "MTK");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_ownable() {
    let attribute = quote! { (Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod Owned {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_ownable_no_initializer() {
    let attribute = quote! { (Ownable) };
    let item = quote! {
      #[starknet::contract]
      pub mod Owned {
          use starknet::ContractAddress;

          #[storage]
          pub struct Storage {}

          #[constructor]
          fn constructor(ref self: ContractState) {
          }
      }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components() {
    let attribute = quote! { (ERC20, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::{ERC20HooksEmptyImpl, DefaultConfig};
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
                self.erc20.initializer("MyToken", "MTK");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components_no_initializer() {
    let attribute = quote! { (ERC20, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::{ERC20HooksEmptyImpl, DefaultConfig};
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components_no_constructor() {
    let attribute = quote! { (ERC20, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::{ERC20HooksEmptyImpl, DefaultConfig};
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_access_control() {
    let attribute = quote! { (AccessControl) };
    let item = quote! {
        #[starknet::contract]
        pub mod Contract {
            use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, default_admin: ContractAddress) {
                self.access_control.initializer();

                self.access_control._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_access_control_no_initializer() {
    let attribute = quote! { (AccessControl) };
    let item = quote! {
        #[starknet::contract]
        pub mod Contract {
            use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_vesting() {
    let attribute = quote! { (Vesting, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod VestingWallet {
            use openzeppelin_finance::vesting::LinearVestingSchedule;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(
                ref self: ContractState,
                beneficiary: ContractAddress,
                start: u64,
                duration: u64,
                cliff_duration: u64,
            ) {
                self.ownable.initializer(beneficiary);
                self.vesting.initializer(start, duration, cliff_duration);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_vesting_no_initializer() {
    let attribute = quote! { (Vesting, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod VestingWallet {
            use openzeppelin_finance::vesting::LinearVestingSchedule;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(
                ref self: ContractState,
                beneficiary: ContractAddress,
                start: u64,
                duration: u64,
                cliff_duration: u64,
            ) {
                self.ownable.initializer(beneficiary);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_vesting_no_schedule() {
    let attribute = quote! { (Vesting, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod VestingWallet {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(
                ref self: ContractState,
                beneficiary: ContractAddress,
                start: u64,
                duration: u64,
                cliff_duration: u64,
            ) {
                self.ownable.initializer(beneficiary);
                self.vesting.initializer(start, duration, cliff_duration);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_no_contract_attribute() {
    let attribute = quote! { (Ownable) };
    let item = quote! {
        pub mod Owned {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_no_body() {
    let attribute = quote! { (ERC20, Ownable) };
    let item = quote! {
        pub mod MyContract;
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_no_components() {
    let attribute = quote! { () };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_invalid_component() {
    let attribute = quote! { (ERC6000, Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_src5() {
    let attribute = quote! { (SRC5) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_initializable() {
    let attribute = quote! { (Initializable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[generate_trait]
            #[abi(per_item)]
            impl ExternalImpl of ExternalTrait {
                #[external(v0)]
                fn initialize(ref self: ContractState) {
                    self.initializable.initialize();
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_initializable_no_initialize_call() {
    let attribute = quote! { (Initializable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_pausable() {
    let attribute = quote! { (Pausable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[generate_trait]
            #[abi(per_item)]
            impl ExternalImpl of ExternalTrait {
                #[external(v0)]
                fn pause(ref self: ContractState) {
                    self.pausable.pause();
                }

                #[external(v0)]
                fn unpause(ref self: ContractState) {
                    self.pausable.unpause();
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_pausable_no_pause_call() {
    let attribute = quote! { (Pausable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[generate_trait]
            #[abi(per_item)]
            impl ExternalImpl of ExternalTrait {
                #[external(v0)]
                fn unpause(ref self: ContractState) {
                    self.pausable.unpause();
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_pausable_no_unpause_call() {
    let attribute = quote! { (Pausable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[generate_trait]
            #[abi(per_item)]
            impl ExternalImpl of ExternalTrait {
                #[external(v0)]
                fn pause(ref self: ContractState) {
                    self.pausable.pause();
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_pausable_no_pause_or_unpause_call() {
    let attribute = quote! { (Pausable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_reentrancy_guard() {
    let attribute = quote! { (ReentrancyGuard) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721() {
    let attribute = quote! { (ERC721) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::erc721::ERC721HooksEmptyImpl;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc721.initializer("MyToken", "MTK", "");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_no_initializer() {
    let attribute = quote! { (ERC721) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::erc721::ERC721HooksEmptyImpl;

            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_no_hooks_impl() {
    let attribute = quote! { (ERC721) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc721.initializer("MyToken", "MTK", "");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc1155() {
    let attribute = quote! { (ERC1155) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::erc1155::ERC1155HooksEmptyImpl;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc1155.initializer("");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc1155_no_initializer() {
    let attribute = quote! { (ERC1155) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::erc1155::ERC1155HooksEmptyImpl;

            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc1155_no_hooks_impl() {
    let attribute = quote! { (ERC1155) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc1155.initializer("");
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_enumerable() {
    let attribute = quote! { (ERC721Enumerable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc721_enumerable.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_enumerable_no_initializer() {
    let attribute = quote! { (ERC721Enumerable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_receiver() {
    let attribute = quote! { (ERC721Receiver) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc721_receiver.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc721_receiver_no_initializer() {
    let attribute = quote! { (ERC721Receiver) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc1155_receiver() {
    let attribute = quote! { (ERC1155Receiver) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc1155_receiver.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc1155_receiver_no_initializer() {
    let attribute = quote! { (ERC1155Receiver) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc2981() {
    let attribute = quote! { (ERC2981) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::common::erc2981::DefaultConfig;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, default_royalty_receiver: ContractAddress) {
                self.erc2981.initializer(default_royalty_receiver, 0);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc2981_no_initializer() {
    let attribute = quote! { (ERC2981) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_token::common::erc2981::DefaultConfig;

            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc2981_no_config() {
    let attribute = quote! { (ERC2981) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, default_royalty_receiver: ContractAddress) {
                self.erc2981.initializer(default_royalty_receiver, 0);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc2981_no_initializer_no_config() {
    let attribute = quote! { (ERC2981) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, default_royalty_receiver: ContractAddress) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_upgradeable() {
    let attribute = quote! { (Upgradeable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[abi(embed_v0)]
            impl UpgradeableImpl of IUpgradeable<ContractState> {
                fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
                    self.upgradeable.upgrade(new_class_hash);
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_upgradeable_no_upgrade_call() {
    let attribute = quote! { (Upgradeable) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[abi(embed_v0)]
            impl UpgradeableImpl of IUpgradeable<ContractState> {
                fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_nonces() {
    let attribute = quote! { (Nonces) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_multisig() {
    let attribute = quote! { (Multisig) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, quorum: u32, signers: Span<ContractAddress>) {
                self.multisig.initializer(quorum, signers);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_multisig_no_initializer() {
    let attribute = quote! { (Multisig) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_timelock_controller() {
    let attribute = quote! { (TimelockController) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(
                ref self: ContractState,
                min_delay: u64,
                proposers: Span<ContractAddress>,
                executors: Span<ContractAddress>,
                admin: ContractAddress,
            ) {
                self.timelock_controller.initializer(min_delay, proposers, executors, admin);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_timelock_controller_no_initializer() {
    let attribute = quote! { (TimelockController) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_votes() {
    let attribute = quote! { (Votes) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;

            #[storage]
            pub struct Storage {}

            // Required for hash computation.
            pub impl SNIP12MetadataImpl of SNIP12Metadata {
                fn name() -> felt252 {
                    "DAPP_NAME" // quote! fails to recognize short strings
                }
                fn version() -> felt252 {
                    "DAPP_VERSION" // quote! fails to recognize short strings
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_votes_no_metadata() {
    let attribute = quote! { (Votes) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_event_struct() {
    let attribute = quote! { (Ownable) };
    let item = quote! {
        #[starknet::contract]
        pub mod Owned {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[event]
            #[derive(Drop, starknet::Event)]
            enum Event {
                Transfer: Transfer,
            }

            // Emitted when tokens are moved from address `from` to address `to`.
            #[derive(Drop, starknet::Event)]
            pub struct Transfer {
                #[key]
                pub from: ContractAddress,
                #[key]
                pub to: ContractAddress,
                pub value: u256,
            }

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc4626() {
    let attribute = quote! { (ERC20, ERC4626) };
    let item = quote! {
        #[starknet::contract]
        pub mod ERC4626Mock {
            use openzeppelin_token::erc20::extensions::erc4626::{
                DefaultConfig, ERC4626DefaultNoLimits, ERC4626DefaultNoFees,
                ERC4626EmptyHooks, ERC4626SelfAssetsManagement,
            };
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            // ERC4626
            #[abi(embed_v0)]
            impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
            // ERC4626MetadataImpl is a custom impl of IERC20Metadata
            #[abi(embed_v0)]
            impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

            // ERC20
            #[abi(embed_v0)]
            impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
            #[abi(embed_v0)]
            impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(
                ref self: ContractState,
                name: ByteArray,
                symbol: ByteArray,
                underlying_asset: ContractAddress,
                initial_supply: u256,
                recipient: ContractAddress,
            ) {
                self.erc20.initializer(name, symbol);
                self.erc20.mint(recipient, initial_supply);
                self.erc4626.initializer(underlying_asset);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor() {
    let attribute = quote! { (Governor) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_governance::governor::DefaultConfig;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.governor.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_no_initializer() {
    let attribute = quote! { (Governor) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use openzeppelin_governance::governor::DefaultConfig;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_no_config() {
    let attribute = quote! { (Governor) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.governor.initializer();
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_core_execution() {
    let attribute = quote! { (GovernorCoreExecution) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_counting_simple() {
    let attribute = quote! { (GovernorCountingSimple) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_settings() {
    let attribute = quote! { (GovernorSettings) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            pub const VOTING_DELAY: u64 = 86400; // 1 day
            pub const VOTING_PERIOD: u64 = 604800; // 1 week
            pub const PROPOSAL_THRESHOLD: u256 = 10;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.governor_settings.initializer(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_settings_no_initializer() {
    let attribute = quote! { (GovernorSettings) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_timelock_execution() {
    let attribute = quote! { (GovernorTimelockExecution) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, timelock_controller: ContractAddress) {
                self.governor_timelock_execution.initializer(timelock_controller);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_timelock_execution_no_initializer() {
    let attribute = quote! { (GovernorTimelockExecution) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_votes_quorum_fraction() {
    let attribute = quote! { (GovernorVotesQuorumFraction) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            pub const QUORUM_NUMERATOR: u256 = 600; // 60%

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, votes_token: ContractAddress) {
                self.governor_votes_quorum_fraction.initializer(votes_token, QUORUM_NUMERATOR);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_votes_quorum_fraction_no_initializer() {
    let attribute = quote! { (GovernorVotesQuorumFraction) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_votes() {
    let attribute = quote! { (GovernorVotes) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, votes_token: ContractAddress) {
                self.governor_votes.initializer(votes_token);
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_votes_no_initializer() {
    let attribute = quote! { (GovernorVotes) };
    let item = quote! {
        #[starknet::contract]
        pub mod MyContract {
            #[storage]
            pub struct Storage {}
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_governor_integration() {
    let attribute = quote! { (Governor, GovernorVotes, GovernorSettings, GovernorCountingSimple, GovernorTimelockExecution, SRC5) };
    let item = quote! {
        #[starknet::contract]
        pub mod GovernorTimelockedMock {
            use openzeppelin_governance::governor::DefaultConfig;
            use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
            use starknet::ContractAddress;

            pub const VOTING_DELAY: u64 = 86400; // 1 day
            pub const VOTING_PERIOD: u64 = 604800; // 1 week
            pub const PROPOSAL_THRESHOLD: u256 = 10;
            pub const QUORUM: u256 = 100_000_000;

            // Governor
            #[abi(embed_v0)]
            impl GovernorImpl = GovernorComponent::GovernorImpl<ContractState>;

            // Extensions external
            #[abi(embed_v0)]
            impl VotesTokenImpl = GovernorVotesComponent::VotesTokenImpl<ContractState>;
            #[abi(embed_v0)]
            impl GovernorSettingsAdminImpl =
                GovernorSettingsComponent::GovernorSettingsAdminImpl<ContractState>;
            #[abi(embed_v0)]
            impl TimelockedImpl =
                GovernorTimelockExecutionComponent::TimelockedImpl<ContractState>;

            // SRC5
            #[abi(embed_v0)]
            impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

            #[storage]
            struct Storage {
            }

            #[constructor]
            fn constructor(
                ref self: ContractState, votes_token: ContractAddress, timelock_controller: ContractAddress,
            ) {
                self.governor.initializer();
                self.governor_votes.initializer(votes_token);
                self.governor_settings.initializer(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD);
                self.governor_timelock_execution.initializer(timelock_controller);
            }

            //
            // SNIP12 Metadata
            //

            // This should be 'DAPP_NAME' and 'DAPP_VERSION' but quote! fails to recognize short strings
            pub impl SNIP12MetadataImpl of SNIP12Metadata {
                fn name() -> felt252 {
                    "DAPP_NAME" // quote! fails to recognize short strings
                }

                fn version() -> felt252 {
                    "DAPP_VERSION" // quote! fails to recognize short strings
                }
            }

            //
            // Locally implemented extensions
            //

            impl GovernorQuorum of GovernorComponent::GovernorQuorumTrait<ContractState> {
                fn quorum(self: @GovernorComponent::ComponentState<ContractState>, timepoint: u64) -> u256 {
                    QUORUM
                }
            }
        }
    };
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

//
// Helpers
//

/// Returns a string representation of the result of the macro expansion,
/// including the token stream, diagnostics and aux data.
fn get_string_result(attr_stream: TokenStream, item_stream: TokenStream) -> String {
    let raw_result = with_components(attr_stream, item_stream);
    format_proc_macro_result(raw_result)
}
