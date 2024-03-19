use openzeppelin::tests::mocks::nonces_mocks::NoncesMock;
use openzeppelin::tests::utils::constants::OWNER;
use openzeppelin::utils::cryptography::interface::INonces;
use openzeppelin::utils::cryptography::nonces::NoncesComponent::InternalTrait;
use openzeppelin::utils::cryptography::nonces::NoncesComponent;

type ComponentState = NoncesComponent::ComponentState<NoncesMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    NoncesComponent::component_state_for_testing()
}

#[test]
fn test_nonces_getter() {
    let state = COMPONENT_STATE();
    let nonce = state.nonces(OWNER());
    assert!(nonce.is_zero());
}

#[test]
fn test_use_nonce() {
    let mut state = COMPONENT_STATE();
    let nonce = state.use_nonce(OWNER());
    assert!(nonce.is_zero());

    let nonce = state.nonces(OWNER());
    assert_eq!(nonce, 1, "use_nonce should increment the nonce by 1");
}

#[test]
fn test_use_checked_nonce() {
    let mut state = COMPONENT_STATE();
    let nonce = state.use_checked_nonce(OWNER(), 0);
    assert!(nonce.is_zero());

    let nonce = state.nonces(OWNER());
    assert_eq!(nonce, 1, "use_checked_nonce should increment the nonce by 1");
}

#[test]
#[should_panic(expected: ('Nonces: invalid nonce',))]
fn test_use_checked_nonce_invalid_current() {
    let mut state = COMPONENT_STATE();
    state.use_checked_nonce(OWNER(), 15);
}
