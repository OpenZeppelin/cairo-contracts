use serde::Serde;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressSerde;
use array::ArrayTrait;
use array::SpanTrait;

// to do: update ID
const ACCOUNT_ID: felt252 = 0x4;

struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

#[account_contract]
mod Account {
    use array::SpanTrait;
    use array::ArrayTrait;
    use ecdsa::check_ecdsa_signature;
    use starknet::contract_address::ContractAddressPartialEq;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_tx_info;

    use option::OptionTrait;
    use super::Call;
    use super::ArrayCallSerde;
    use super::ArrayCallDrop;
    use super::ACCOUNT_ID;

    use openzeppelin::introspection::erc165::ERC165Contract;

    //
    // Storage and Constructor
    //

    struct Storage {
        public_key: felt252, 
    }

    #[constructor]
    fn constructor(_public_key: felt252) {
        ERC165Contract::register_interface(ACCOUNT_ID);
        public_key::write(_public_key);
    }

    //
    // Externals
    //

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Array<felt252>> {
        assert_valid_transaction();
        let mut res = ArrayTrait::new();
        _execute_calls(calls, res)
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) {
        assert_valid_transaction()
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) {
        assert_valid_transaction()
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) {
        assert_valid_transaction()
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
    fn is_valid_signature(message: felt252, sig_r: felt252, sig_s: felt252) -> bool {
        let _public_key: felt252 = public_key::read();
        check_ecdsa_signature(message, _public_key, sig_r, sig_s)
    // to do:
    // return magic value or false
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        ERC165Contract::supports_interface(interface_id)
    }

    //
    // Internals
    //

    fn _execute_calls(
        mut calls: Array<Call>, mut res: Array<Array<felt252>>
    ) -> Array<Array<felt252>> {
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

    fn _execute_single_call(mut call: Call) -> Array<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata).unwrap_syscall()
    }

    fn assert_only_self() {
        let caller = get_caller_address();
        let self = get_contract_address();
        assert(self == caller, 'Account: unauthorized.');
    }

    fn assert_valid_transaction() {
        let tx_info = unbox(get_tx_info());
        let tx_hash = tx_info.transaction_hash;
        let signature = tx_info.signature;

        assert(signature.len() == 2_u32, 'bad signature length');

        let is_valid = is_valid_signature(tx_hash, *signature.at(0_u32), *signature.at(1_u32));

        assert(is_valid, 'Invalid signature.');
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
    match gas::get_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('Out of gas');
            panic(data);
        },
    }
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

    match gas::get_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('Out of gas');
            panic(data);
        },
    }

    curr_output.append(Serde::<Call>::deserialize(ref serialized)?);
    deserialize_array_call_helper(ref serialized, curr_output, remaining - 1)
}
