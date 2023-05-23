use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use serde::deserialize_array_helper;
use serde::serialize_array_helper;
use starknet::ContractAddress;

use openzeppelin::account::interface::Call;

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

    use openzeppelin::account::interface::ERC1271_VALIDATED;
    use openzeppelin::account::interface::IAccount;
    use openzeppelin::account::interface::IACCOUNT_ID;
    use openzeppelin::introspection::erc165::ERC165;

    use super::Call;
    use super::QUERY_VERSION;
    use super::SpanSerde;
    use super::TRANSACTION_VERSION;

    struct Storage {
        public_key: felt252
    }

    impl AccountImpl of IAccount {
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

        fn __validate_declare__(class_hash: felt252) -> felt252 {
            validate_transaction()
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

    #[constructor]
    fn constructor(_public_key: felt252) {
        initializer(_public_key);
    }

    //
    // Externals
    //

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
        AccountImpl::__execute__(calls)
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        AccountImpl::__validate__(calls)
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        AccountImpl::__validate_declare__(class_hash)
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

    //
    // View
    //

    #[view]
    fn get_public_key() -> felt252 {
        public_key::read()
    }

    #[view]
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32 {
        AccountImpl::is_valid_signature(message, signature)
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        AccountImpl::supports_interface(interface_id)
    }

    //
    // Internals
    //

    #[internal]
    fn initializer(_public_key: felt252) {
        ERC165::register_interface(IACCOUNT_ID);
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
    fn _is_valid_signature(message: felt252, signature: Span<felt252>) -> bool {
        let valid_length = signature.len() == 2_u32;

        if valid_length {
            check_ecdsa_signature(
                message, public_key::read(), *signature.at(0_u32), *signature.at(1_u32)
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

impl SpanSerde<
    T, impl TSerde: Serde<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
> of Serde<Span<T>> {
    fn serialize(self: @Span<T>, ref output: Array<felt252>) {
        (*self).len().serialize(ref output);
        serialize_array_helper(*self, ref output);
    }
    fn deserialize(ref serialized: Span<felt252>) -> Option<Span<T>> {
        let length = *serialized.pop_front()?;
        let mut arr = ArrayTrait::new();
        Option::Some(deserialize_array_helper(ref serialized, arr, length)?.span())
    }
}
