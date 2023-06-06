use openzeppelin::security::initializable::Initializable;

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    assert(!Initializable::is_initialized(), 'Should not be initialized');
    Initializable::initialize();
    assert(Initializable::is_initialized(), 'Should be initialized');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Initializable: is initialized', ))]
fn test_initialize_when_initialized() {
    Initializable::initialize();
    Initializable::initialize();
}
