// // use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
// use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;

// use openzeppelin::tests::mocks::erc2981_mocks::ERC2981Mock;
// use openzeppelin::tests::utils::constants::{OTHER, OWNER, ZERO};
// use openzeppelin::token::common::erc2981::ERC2981Component::{ERC2981Impl, InternalImpl};
// use openzeppelin::token::common::erc2981::ERC2981Component;
// use openzeppelin::token::common::erc2981::interface::IERC2981_ID;
// use openzeppelin::token::common::erc2981::{IERC2981Dispatcher, IERC2981DispatcherTrait};

// use starknet::{ContractAddress, contract_address_const};

// type ComponentState = ERC2981Component::ComponentState<ERC2981Mock::ContractState>;

// fn CONTRACT_STATE() -> ERC2981Mock::ContractState {
//     ERC2981Mock::contract_state_for_testing()
// }

// fn COMPONENT_STATE() -> ComponentState {
//     ERC2981Component::component_state_for_testing()
// }

// fn DEFAULT_RECEIVER() -> ContractAddress {
//     contract_address_const::<'DEFAULT_RECEIVER'>()
// }

// fn RECEIVER() -> ContractAddress {
//     contract_address_const::<'RECEIVER'>()
// }

// // 0.5% (default denominator is 10000)
// const DEFAULT_FEE_NUMERATOR: u256 = 50;
// // 5% (default denominator is 10000)
// const FEE_NUMERATOR: u256 = 500;

// fn setup() -> ComponentState {
//     let mut state = COMPONENT_STATE();
//     state.initializer(DEFAULT_RECEIVER(), DEFAULT_FEE_NUMERATOR);
//     state
// }

// #[test]
// fn test_default_royalty() {
//     let mut state = setup();
//     let token_id = 12;
//     let sale_price = 1_000_000;
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 5000, "Default fees incorrect");

//     state._set_default_royalty(RECEIVER(), FEE_NUMERATOR);

//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 50000, "Default fees incorrect");
// }

// #[test]
// fn test_token_royalty_token() {
//     let mut state = setup();
//     let token_id = 12;
//     let another_token_id = 13;
//     let sale_price = 1_000_000;
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 5000, "Wrong royalty amount");
//     let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 5000, "Wrong royalty amount");

//     state._set_token_royalty(token_id, RECEIVER(), FEE_NUMERATOR);
//     let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 5000, "Wrong royalty amount");
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 50000, "Wrong royalty amount");

//     state._reset_token_royalty(token_id);
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 5000, "Wrong royalty amount");
// }

// //
// // check IERC2981_ID is registered

// #[test]
// fn test_token_royalty_set_twice() {
//     let mut state = setup();
//     let token_id = 12;
//     let sale_price = 1_000_000;

//     state._set_token_royalty(token_id, RECEIVER(), FEE_NUMERATOR);
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 50000, "Wrong royalty amount");

//     state._set_token_royalty(token_id, OTHER(), FEE_NUMERATOR);
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, OTHER(), "Default receiver incorrect");
//     assert_eq!(amount, 50000, "Wrong royalty amount");
// }

// #[test]
// #[should_panic(expected: ("Invalid token royalty receiver",))]
// fn test_token_royalty_with_zero_receiver() {
//     let mut state = setup();
//     let token_id = 12;
//     state._set_token_royalty(token_id, ZERO(), FEE_NUMERATOR);
// }

// #[test]
// fn test_token_royalty_with_zero_royalty_fraction() {
//     let mut state = setup();
//     let token_id = 12;
//     let sale_price = 1_000_000;

//     state._set_token_royalty(token_id, RECEIVER(), 0);
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 0, "Wrong royalty amount");
// }

// #[test]
// #[should_panic(expected: ("Invalid token royalty",))]
// fn test_token_royalty_with_invalid_fee_numerator() {
//     let mut state = setup();
//     let token_id = 12;
//     state._set_token_royalty(token_id, RECEIVER(), state._fee_denominator() + 1);
// }

// #[test]
// #[should_panic(expected: ("Invalid default royalty receiver",))]
// fn test_default_royalty_with_zero_receiver() {
//     let mut state = setup();

//     state._set_default_royalty(ZERO(), FEE_NUMERATOR);
// }

// #[test]
// fn test_default_royalty_with_zero_royalty_fraction() {
//     let mut state = setup();
//     let token_id = 12;
//     let sale_price = 1_000_000;

//     state._set_default_royalty(DEFAULT_RECEIVER(), 0);
//     let (receiver, amount) = state.royalty_info(token_id, sale_price);
//     assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
//     assert_eq!(amount, 0, "Wrong royalty amount");
// }

// #[test]
// #[should_panic(expected: ("Invalid default royalty",))]
// fn test_default_royalty_with_invalid_fee_numerator() {
//     let mut state = setup();

//     state._set_default_royalty(DEFAULT_RECEIVER(), state._fee_denominator() + 1);
// }

// #[test]
// fn test_check_ierc2981_interface_is_registered() {
//     let _state = setup();
//     let mock_state = CONTRACT_STATE();

//     let supports_ierc2981 = mock_state.supports_interface(IERC2981_ID);
//     assert!(supports_ierc2981);
// }


