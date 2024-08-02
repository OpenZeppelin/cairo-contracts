use openzeppelin_token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_utils::test_utils::events::EventSpyExt;
use snforge_std::EventSpy;
use starknet::ContractAddress;

#[generate_trait]
pub impl ERC20SpyHelpersImpl of ERC20SpyHelpers {
    fn assert_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    ) {
        let expected = ERC20Component::Event::Approval(Approval { owner, spender, value });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    ) {
        self.assert_event_approval(contract, owner, spender, value);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    ) {
        let expected = ERC20Component::Event::Transfer(Transfer { from, to, value });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    ) {
        self.assert_event_transfer(contract, from, to, value);
        self.assert_no_events_left_from(contract);
    }
}
