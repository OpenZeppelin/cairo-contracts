use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, SYMBOL};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_token::erc20::interface::IERC20Dispatcher;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
use starknet::ContractAddress;

pub fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::declare_and_deploy("DualCaseERC20Mock", calldata);
    IERC20Dispatcher { contract_address: address }
}

#[generate_trait]
pub impl ERC20SpyHelpersImpl of ERC20SpyHelpers {
    fn assert_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("Approval"));
        keys.append_serde(owner);
        keys.append_serde(spender);

        let mut data = array![];
        data.append_serde(value);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    ) {
        self.assert_event_approval(contract, owner, spender, value);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("Transfer"));
        keys.append_serde(from);
        keys.append_serde(to);

        let mut data = array![];
        data.append_serde(value);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    ) {
        self.assert_event_transfer(contract, from, to, value);
        self.assert_no_events_left_from(contract);
    }
}
