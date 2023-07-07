use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use serde::deserialize_array_helper;
use serde::serialize_array_helper;
use starknet::ContractAddress;

use openzeppelin::account::interface::Call;
use openzeppelin::utils::serde::SpanSerde;

const TRANSACTION_VERSION: felt252 = 1;
// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;

#[abi]
trait AccountABI {
    #[external]
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
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
    fn is_valid_signature(hash: felt252, signature: Array<felt252>) -> felt252;
    #[view]
    fn supports_interface(interface_id: felt252) -> bool;
}

// Entry points case-convention is enforced by the protocol
#[abi]
trait AccountABICamel {
    #[external]
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
    #[external]
    fn __validate__(calls: Array<Call>) -> felt252;
    #[external]
    fn __validate_declare__(classHash: felt252) -> felt252;
    #[external]
    fn __validate_deploy__(
        classHash: felt252, contractAddressSalt: felt252, _publicKey: felt252
    ) -> felt252;
    #[external]
    fn setPublicKey(newPublicKey: felt252);
    #[view]
    fn getPublicKey() -> felt252;
    #[view]
    fn isValidSignature(hash: felt252, signature: Array<felt252>) -> felt252;
    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool;
}

#[account_contract]
mod Account {
    use array::SpanTrait;
    use array::ArrayTrait;
    use box::BoxTrait;
    use ecdsa::check_ecdsa_signature;
    use option::OptionTrait;
    use serde::ArraySerde;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use zeroable::Zeroable;

    use openzeppelin::account::interface::ISRC6;
    use openzeppelin::account::interface::ISRC6Camel;
    use openzeppelin::account::interface::IDeclarer;
    use openzeppelin::account::interface::ISRC6_ID;
    use openzeppelin::introspection::src5::ISRC5;
    use openzeppelin::introspection::src5::SRC5;

    use super::Call;
    use super::QUERY_VERSION;
    use super::SpanSerde;
    use super::TRANSACTION_VERSION;

    struct Storage {
        public_key: felt252
    }

    #[constructor]
    fn constructor(_public_key: felt252) {
        initializer(_public_key);
    }

    impl SRC6Impl of ISRC6 {
        fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
            // Avoid calls from other contracts
            // https://github.com/OpenZeppelin/cairo-contracts/issues/344
            let sender = get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');

            // Check tx version
            let tx_info = get_tx_info().unbox();
            let version = tx_info.version;
            if version != TRANSACTION_VERSION {
                assert(version == QUERY_VERSION, 'Account: invalid tx version');
            }

            _execute_calls(calls)
        }

        fn __validate__(mut calls: Array<Call>) -> felt252 {
            validate_transaction()
        }

        fn is_valid_signature(hash: felt252, signature: Array<felt252>) -> felt252 {
            if _is_valid_signature(hash, signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    impl SRC6CamelImpl of ISRC6Camel {
        fn isValidSignature(hash: felt252, signature: Array<felt252>) -> felt252 {
            SRC6Impl::is_valid_signature(hash, signature)
        }
    }

    impl DeclarerImpl of IDeclarer {
        fn __validate_declare__(class_hash: felt252) -> felt252 {
            validate_transaction()
        }
    }

    impl SRC5Impl of ISRC5 {
        fn supports_interface(interface_id: felt252) -> bool {
            SRC5::supports_interface(interface_id)
        }
    }

    //
    // Externals
    //

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
        SRC6Impl::__execute__(calls)
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        SRC6Impl::__validate__(calls)
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        DeclarerImpl::__validate_declare__(class_hash)
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252 {
        validate_transaction()
    }

    #[external]
    fn set_public_key(new_public_key: felt252) {
        assert_only_self();
        public_key::write(new_public_key);
    }

    #[external]
    fn setPublicKey(newPublicKey: felt252) {
        set_public_key(newPublicKey);
    }

    //
    // View
    //

    #[view]
    fn get_public_key() -> felt252 {
        public_key::read()
    }

    #[view]
    fn getPublicKey() -> felt252 {
        get_public_key()
    }

    #[view]
    fn is_valid_signature(hash: felt252, signature: Array<felt252>) -> felt252 {
        SRC6Impl::is_valid_signature(hash, signature)
    }

    #[view]
    fn isValidSignature(hash: felt252, signature: Array<felt252>) -> felt252 {
        is_valid_signature(hash, signature)
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        SRC5Impl::supports_interface(interface_id)
    }

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        supports_interface(interfaceId)
    }

    //
    // Internals
    //

    #[internal]
    fn initializer(_public_key: felt252) {
        SRC5::register_interface(ISRC6_ID);
        public_key::write(_public_key);
    }

    #[internal]
    fn assert_only_self() {
        let caller = get_caller_address();
        let self = get_contract_address();
        assert(self == caller, 'Account: unauthorized');
    }

    #[internal]
    fn validate_transaction() -> felt252 {
        let tx_info = get_tx_info().unbox();
        let tx_hash = tx_info.transaction_hash;
        let signature = tx_info.signature;
        assert(_is_valid_signature(tx_hash, signature), 'Account: invalid signature');
        starknet::VALIDATED
    }

    #[internal]
    fn _is_valid_signature(hash: felt252, signature: Span<felt252>) -> bool {
        let valid_length = signature.len() == 2_u32;

        if valid_length {
            check_ecdsa_signature(
                hash, public_key::read(), *signature.at(0_u32), *signature.at(1_u32)
            )
        } else {
            false
        }
    }

    #[internal]
    fn _execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
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
            };
        };
        res
    }

    #[internal]
    fn _execute_single_call(call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
    }
}
