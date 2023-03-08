const ACCOUNT_ID: felt = 0x4;

struct AccountCall {
    to: ContractAddress,
    selector: felt,
    calldata: Array::<felt>
}

#[account_contract]
mod Account {
    use ecdsa::check_ecdsa_signature;
    use starknet::contract_address::contract_address_to_felt;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_tx_info;

    use openzeppelin::account::ACCOUNT_ID;
    use openzeppelin::account::AccountCall;
    use openzeppelin::introspection::erc165::ERC165Contract;

    struct Storage {
        public_key: felt,
    }

    #[constructor]
    fn constructor(_public_key: felt) {
        ERC165Contract::register_interface(ACCOUNT_ID);
        public_key::write(_public_key);
    }

    #[external]
    fn __execute__(calls: Array::<AccountCall>) {
        assert_valid_transaction();

        // let res: Array::<felt>;
        //
        // for call in calls {
        //   _res = _call_contract(call);
        //   res.append(_res);
        // }
        //
        // return res;
    }

    #[external]
    fn __validate__(
        contract_address: ContractAddress,
        entry_point_selector: felt,
        calldata: Array::<felt>
    ) {
        assert_valid_transaction()
    }

    #[external]
    fn __validate_declare__(class_hash: felt) {
        assert_valid_transaction()
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt,
        contract_address_salt: felt,
        _public_key: felt
    ) {
        assert_valid_transaction()
    }

    #[external]
    fn set_public_key(new_public_key: felt) {
        assert_only_self();
        public_key::write(new_public_key);
    }

    #[view]
    fn get_public_key() -> felt {
        public_key::read()
    }

    #[view]
    fn is_valid_signature(message: felt, sig_r: felt, sig_s: felt) -> bool {
        let _public_key: felt = public_key::read();
        check_ecdsa_signature(message, _public_key, sig_r, sig_s)
    }

    // ERC165
    #[view]
    fn supports_interface(interface_id: felt) -> bool {
        ERC165Contract::supports_interface(interface_id)
    }

    // internals

    fn assert_only_self() {
        let caller = starknet::get_caller_address();
        let self = starknet::get_contract_address();
        let a = contract_address_to_felt(caller);
        let b = contract_address_to_felt(self);
        assert(a == b, 'Account: unauthorized.');
    }

    fn assert_valid_transaction() {
        let tx_info = unbox(get_tx_info());
        let tx_hash = tx_info.transaction_hash;
        let signature = tx_info.signature;

        assert(signature.len() == 2_u32, 'bad signature length');

        let is_valid = is_valid_signature(
            tx_hash,
            *signature.at(0_u32),
            *signature.at(1_u32)
        );

        assert(is_valid, 'Invalid signature.');
    }

    fn call_contract(call: AccountCall) -> felt {
        starknet::call_contract_syscall(
            call.to, call.selector, call.calldata
        ).unwrap_syscall()
    }
}
