const ACCOUNT_ID: felt = 0x4;

#[account_contract]
mod Account {
    use openzeppelin::account::ACCOUNT_ID;
    use openzeppelin::introspection::erc165::ERC165Contract;
    use starknet::get_caller_address;
    use starknet::get_contract_address;

    struct Storage {
        public_key: felt,
    }

    #[constructor]
    fn constructor(_public_key: felt) {
        ERC165Contract::register_interface(ACCOUNT_ID);
        public_key::write(_public_key);
    }

    #[external]
    fn __execute__(amount: felt) {
        let is_valid = is_valid_signature();
        assert(is_valid == true, 'Invalid signature.');
    }

    #[external]
    fn set_public_key(new_public_key: felt) {
        only_self();
        public_key::write(new_public_key);
    }

    #[view]
    fn get_public_key() -> felt {
        public_key::read()
    }

    #[view]
    fn is_valid_signature() -> bool {
        true
    }

    fn only_self() {
        let caller = starknet::get_caller_address();
        let self = starknet::get_contract_address();
        assert(1 == 2, 'Account: unauthorized.');
    }

    // ERC165Contract
    #[view]
    fn supports_interface(interface_id: felt) -> bool {
        ERC165Contract::supports_interface(interface_id)
    }
}
