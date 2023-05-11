use starknet::ContractAddress;
use openzeppelin::utils::check_gas;

const ERC165_ACCOUNT_ID: u32 = 0xa66bd575_u32;
const ERC1271_VALIDATED: u32 = 0x1626ba7e_u32;

const TRANSACTION_VERSION: felt252 = 1;
// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

#[abi]
trait IAccount {
    #[external]
    fn __execute__(calls: Array<Call>) -> Array<Array<felt252>>;
    #[external]
    fn __validate__(calls: Array<Call>) -> felt252;
    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252;
    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252;
    #[external]
    fn set_public_key(new_public_key: felt252);
    #[view]
    fn get_public_key() -> felt252;
    #[view]
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32;
    #[view]
    fn supports_interface(interface_id: u32) -> bool;
}

#[account_contract]
mod Account {
    use array::SpanTrait;
    use array::ArrayTrait;
    use box::BoxTrait;
    use ecdsa::check_ecdsa_signature;
    use serde::ArraySerde;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use option::OptionTrait;
    use zeroable::Zeroable;

    use super::Call;
    use super::ERC165_ACCOUNT_ID;
    use super::ERC1271_VALIDATED;
    use super::IAccount;
    use super::TRANSACTION_VERSION;
    use super::QUERY_VERSION;

    use openzeppelin::introspection::erc165::ERC165;
    use openzeppelin::utils::check_gas;
    use openzeppelin::utils::span_to_array;

    impl Account of IAccount {
        fn __execute__(mut calls: Array<Call>) -> Array<Array<felt252>> {
            // avoid calls from other contracts
            // https://github.com/OpenZeppelin/cairo-contracts/issues/344
            let sender = get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');

            // check tx version
            let tx_info = get_tx_info().unbox();
            let version = tx_info.version;
            if version != TRANSACTION_VERSION { // > operator not defined for felt252
                assert(version == QUERY_VERSION, 'Account: invalid tx version');
            }

            _execute_calls(calls)
        }

        fn __validate__(mut calls: Array<Call>) -> felt252 {
            _validate_transaction()
        }

        fn __validate_declare__(class_hash: felt252) -> felt252 {
            _validate_transaction()
        }

        fn __validate_deploy__(
            class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
        ) -> felt252 {
            _validate_transaction()
        }

        fn set_public_key(new_public_key: felt252) {
            _assert_only_self();
            public_key::write(new_public_key);
        }

        fn get_public_key() -> felt252 {
            public_key::read()
        }

        fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32 {
            if _is_valid_signature(message, signature.span()) {
                ERC1271_VALIDATED
            } else {
                0_u32
            }
        }

        fn supports_interface(interface_id: u32) -> bool {
            ERC165::supports_interface(interface_id)
        }
    }

    struct Storage {
        public_key: felt252
    }

    #[constructor]
    fn constructor(_public_key: felt252) {
        ERC165::register_interface(ERC165_ACCOUNT_ID);
        public_key::write(_public_key);
    }

    //
    // Externals
    //

    // TODO: Use Span in the inner Array of the return type
    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Array<felt252>> {
        Account::__execute__(calls)
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        Account::__validate__(calls)
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        Account::__validate_declare__(class_hash)
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252 {
        Account::__validate_deploy__(class_hash, contract_address_salt, _public_key)
    }

    #[external]
    fn set_public_key(new_public_key: felt252) {
        Account::set_public_key(new_public_key)
    }

    //
    // View
    //

    #[view]
    fn get_public_key() -> felt252 {
        Account::get_public_key()
    }

    #[view]
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32 {
        Account::is_valid_signature(message, signature)
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        Account::supports_interface(interface_id)
    }

    //
    // Internals
    //

    #[internal]
    fn _assert_only_self() {
        let caller = get_caller_address();
        let self = get_contract_address();
        assert(self == caller, 'Account: unauthorized');
    }

    #[internal]
    fn _validate_transaction() -> felt252 {
        let tx_info = get_tx_info().unbox();
        let tx_hash = tx_info.transaction_hash;
        let signature = tx_info.signature;
        assert(_is_valid_signature(tx_hash, signature), 'Account: invalid signature');
        starknet::VALIDATED
    }

    #[internal]
    fn _is_valid_signature(message: felt252, signature: Span<felt252>) -> bool {
        let valid_length = signature.len() == 2_u32;

        valid_length
            & check_ecdsa_signature(
                message, public_key::read(), *signature.at(0_u32), *signature.at(1_u32)
            )
    }

    #[internal]
    fn _execute_calls(mut calls: Array<Call>) -> Array<Array<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(call);
                    res.append(_res);
                },
                Option::None(_) => {
                    break ();
                },
            }
            check_gas();
        };
        res
    }

    #[internal]
    fn _execute_single_call(call: Call) -> Array<felt252> {
        let Call{to, selector, calldata } = call;

        let res = starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall();
        span_to_array(res)
    }
}
