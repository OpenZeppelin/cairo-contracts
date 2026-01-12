use openzeppelin_interfaces::erc6909::IERC6909_METADATA_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::erc6909::ERC6909MetadataMock;
use openzeppelin_testing::constants::{DECIMALS, NAME, SYMBOL, TOKEN_ID};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::test_address;
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent;
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent::{
    ERC6909MetadataImpl, InternalImpl,
};

type ComponentState = ERC6909MetadataComponent::ComponentState<ERC6909MetadataMock::ContractState>;

fn CONTRACT_STATE() -> ERC6909MetadataMock::ContractState {
    ERC6909MetadataMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909MetadataComponent::component_state_for_testing()
}

#[test]
fn test_initializer_registers_interface_and_sets_metadata() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let contract_address = test_address();

    let mut spy = spy_events();
    state.initializer(TOKEN_ID, NAME(), SYMBOL(), DECIMALS);

    spy.assert_event_name_updated(contract_address, TOKEN_ID, NAME());
    spy.assert_event_symbol_updated(contract_address, TOKEN_ID, SYMBOL());
    spy.assert_only_event_decimals_updated(contract_address, TOKEN_ID, DECIMALS);
    assert!(mock_state.supports_interface(IERC6909_METADATA_ID));
    assert!(mock_state.supports_interface(ISRC5_ID));
    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
fn test_default_getters_are_empty_or_zero() {
    let state = COMPONENT_STATE();

    let empty: ByteArray = "";
    assert_eq!(state.name(TOKEN_ID), empty);
    assert_eq!(state.symbol(TOKEN_ID), empty);
    assert_eq!(state.decimals(TOKEN_ID), 0);
}

#[test]
fn test__set_token_name() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    let mut spy = spy_events();
    state._set_token_name(TOKEN_ID, NAME());

    spy.assert_only_event_name_updated(contract_address, TOKEN_ID, NAME());
    assert_eq!(state.name(TOKEN_ID), NAME());
}

#[test]
fn test__set_token_symbol() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    let mut spy = spy_events();
    state._set_token_symbol(TOKEN_ID, SYMBOL());

    spy.assert_only_event_symbol_updated(contract_address, TOKEN_ID, SYMBOL());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
}

#[test]
fn test__set_token_decimals() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    let mut spy = spy_events();
    state._set_token_decimals(TOKEN_ID, DECIMALS);

    spy.assert_only_event_decimals_updated(contract_address, TOKEN_ID, DECIMALS);
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
fn test_set_all_metadata_individually() {
    let mut state = COMPONENT_STATE();

    state._set_token_name(TOKEN_ID, NAME());
    state._set_token_symbol(TOKEN_ID, SYMBOL());
    state._set_token_decimals(TOKEN_ID, DECIMALS);

    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[generate_trait]
impl ERC6909MetadataSpyHelpersImpl of ERC6909MetadataSpyHelpers {
    fn assert_event_name_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_name: ByteArray,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("ERC6909NameUpdated"))
            .key(id)
            .data(new_name);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_name_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_name: ByteArray,
    ) {
        self.assert_event_name_updated(contract, id, new_name);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_symbol_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_symbol: ByteArray,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("ERC6909SymbolUpdated"))
            .key(id)
            .data(new_symbol);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_symbol_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_symbol: ByteArray,
    ) {
        self.assert_event_symbol_updated(contract, id, new_symbol);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_decimals_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_decimals: u8,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("ERC6909DecimalsUpdated"))
            .key(id)
            .data(new_decimals);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_decimals_updated(
        ref self: EventSpy, contract: starknet::ContractAddress, id: u256, new_decimals: u8,
    ) {
        self.assert_event_decimals_updated(contract, id, new_decimals);
        self.assert_no_events_left_from(contract);
    }
}
