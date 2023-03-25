use openzeppelin::security::reentrancyguard::ReentrancyGuard;

#[test]
#[available_gas(2000000)]
fn test_reentrancyguard_start() {
    assert(!ReentrancyGuard::_entered::read(),'Should be false');
    ReentrancyGuard::start();
    assert(ReentrancyGuard::_entered::read(),'Should be true');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ReentrancyGuard: reentrant call', ))]
fn test_start_when_started() {
    ReentrancyGuard::start();
    ReentrancyGuard::start();
}
