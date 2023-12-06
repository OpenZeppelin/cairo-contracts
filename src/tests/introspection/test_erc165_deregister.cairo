use openzeppelin::tests::mocks::erc165_deregister_mock::ERC165DeregisterMock::ERC165DeregisterMockImpl;
use openzeppelin::tests::mocks::erc165_deregister_mock::ERC165DeregisterMock;

const ID_1: felt252 = 0x12345678;
const ID_2: felt252 = 0x87654321;

fn STATE() -> ERC165DeregisterMock::ContractState {
    ERC165DeregisterMock::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_deregister_interface() {
    let mut state = STATE();

    state.register_interface(ID_1);
    state.register_interface(ID_2);

    assert(state.supports_interface(ID_1), 'Should support ID_1');
    assert(state.supports_interface(ID_2), 'Should support ID_2');

    state.deregister_erc165_interface(ID_1);
    state.deregister_erc165_interface(ID_2);

    assert(!state.supports_interface(ID_1), 'Should not support ID_1');
    assert(!state.supports_interface(ID_2), 'Should not support ID_1');
}

#[test]
#[available_gas(2000000)]
fn test_deregister_interface_not_registered() {
    let mut state = STATE();

    assert(!state.supports_interface(ID_1), 'Should not support ID_1');
    assert(!state.supports_interface(ID_2), 'Should not support ID_1');

    state.deregister_erc165_interface(ID_1);
    state.deregister_erc165_interface(ID_2);

    assert(!state.supports_interface(ID_1), 'Should not support ID_1');
    assert(!state.supports_interface(ID_2), 'Should not support ID_1');
}
