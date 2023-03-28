use serde::Serde;
use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressSerde;
use openzeppelin::utils::check_gas;

const ERC165_ACCOUNT_ID: u32 = 0xa66bd575_u32;
const ERC1271_VALIDATED: u32 = 0x1626ba7e_u32;

const TRANSACTION_VERSION: felt252 = 1;
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457; // 2**128 + TRANSACTION_VERSION

struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

#[account_contract]
mod Account {
    use box::BoxTrait;
    use array::SpanTrait;
    use array::ArrayTrait;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use ecdsa::check_ecdsa_signature;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::contract_address::ContractAddressPartialEq;
    use starknet::contract_address::ContractAddressZeroable;

    use super::Call;
    use super::ArrayCallSerde;
    use super::ArrayCallDrop;
    use super::ERC165_ACCOUNT_ID;
    use super::ERC1271_VALIDATED;
    use super::TRANSACTION_VERSION;
    use super::QUERY_VERSION;

    use openzeppelin::introspection::erc165::ERC165Contract;
    use openzeppelin::utils::check_gas;

    //
    // Storage and Constructor
    //

    struct Storage {
        public_key: felt252, 
    }

    #[constructor]
    fn constructor(_public_key: felt252) {
        ERC165Contract::register_interface(ERC165_ACCOUNT_ID);
        public_key::write(_public_key);
    }

    //
    // Externals
    //

    // todo: fix Span serde
    // #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
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

        _execute_calls(calls, ArrayTrait::new())
    }

    // todo: fix Span serde
    // #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        _validate_transaction()

    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        _validate_transaction()
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252,
        contract_address_salt: felt252,
        _public_key: felt252
    ) -> felt252 {
        _validate_transaction()
    }

    #[external]
    fn set_public_key(new_public_key: felt252) {
        _assert_only_self();
        public_key::write(new_public_key);
    }

    //
    // View
    //

    #[view]
    fn get_public_key() -> felt252 {
        public_key::read()
    }

    // todo: fix Span serde
    // #[view]
    fn is_valid_signature(message: felt252, signature: Span<felt252>) -> u32 {
        if _is_valid_signature(message, signature) {
            ERC1271_VALIDATED
        } else {
            0_u32
        }
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        ERC165Contract::supports_interface(interface_id)
    }

    //
    // Internals
    //

    fn _assert_only_self() {
        let caller = get_caller_address();
        let self = get_contract_address();
        assert(self == caller, 'Account: unauthorized');
    }

    fn _validate_transaction() -> felt252 {
        let tx_info = get_tx_info().unbox();
        let tx_hash = tx_info.transaction_hash;
        let signature = tx_info.signature;
        assert(_is_valid_signature(tx_hash, signature), 'Account: invalid signature');
        starknet::VALIDATED
    }

    fn _is_valid_signature(message: felt252, signature: Span<felt252>) -> bool {
        let valid_length = signature.len() == 2_u32;
        
        valid_length & check_ecdsa_signature(
            message,
            public_key::read(),
            *signature.at(0_u32),
            *signature.at(1_u32)
        )
    }

    fn _execute_calls(mut calls: Array<Call>, mut res: Array<Span<felt252>>) -> Array<Span<felt252>> {
        check_gas();
        match calls.pop_front() {
            Option::Some(call) => {
                let _res = _execute_single_call(call);
                res.append(_res);
                return _execute_calls(calls, res);
            },
            Option::None(_) => {
                return res;
            },
        }
    }

    fn _execute_single_call(mut call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
    }
}

impl ArrayCallDrop of Drop::<Array<Call>>;

impl CallSerde of Serde::<Call> {
    fn serialize(ref output: Array<felt252>, input: Call) {
        let Call{to, selector, calldata } = input;
        Serde::serialize(ref output, to);
        Serde::serialize(ref output, selector);
        Serde::serialize(ref output, calldata);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<Call> {
        let to = Serde::<ContractAddress>::deserialize(ref serialized)?;
        let selector = Serde::<felt252>::deserialize(ref serialized)?;
        let calldata = Serde::<Array::<felt252>>::deserialize(ref serialized)?;
        Option::Some(Call { to, selector, calldata })
    }
}

impl ArrayCallSerde of Serde::<Array<Call>> {
    fn serialize(ref output: Array<felt252>, mut input: Array<Call>) {
        Serde::<usize>::serialize(ref output, input.len());
        serialize_array_call_helper(ref output, input);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<Array<Call>> {
        let length = *serialized.pop_front()?;
        let mut arr = ArrayTrait::new();
        deserialize_array_call_helper(ref serialized, arr, length)
    }
}

fn serialize_array_call_helper(ref output: Array<felt252>, mut input: Array<Call>) {
    check_gas();
    match input.pop_front() {
        Option::Some(value) => {
            Serde::<Call>::serialize(ref output, value);
            serialize_array_call_helper(ref output, input);
        },
        Option::None(_) => {},
    }
}

fn deserialize_array_call_helper(
    ref serialized: Span<felt252>, mut curr_output: Array<Call>, remaining: felt252
) -> Option<Array<Call>> {
    if remaining == 0 {
        return Option::Some(curr_output);
    }

    check_gas();

    curr_output.append(Serde::<Call>::deserialize(ref serialized)?);
    deserialize_array_call_helper(ref serialized, curr_output, remaining - 1)
}
