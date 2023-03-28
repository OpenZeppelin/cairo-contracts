use starknet::ContractAddress;
use array::ArrayTrait;

const IERC1155_ID: u32 = 0xd9b67a26_u32;
const IERC1155_METADATA_ID: u32 = 0x0e89341c_u32;
const IERC1155_RECEIVER_ID: u32 = 0x4e2312e0_u32;
const ON_ERC1155_RECEIVED_SELECTOR: u32 = 0xf23a6e61_u32;
const ON_ERC1155_BATCH_RECEIVED_SELECTOR: u32 = 0xbc197c81_u32;

#[abi]
trait IERC1155 {
    // IERC1155
    fn balance_of(account: ContractAddress, id: u256) -> u256;
    fn balance_of_batch(accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256>;
    fn is_approved_for_all(account: ContractAddress, operator: ContractAddress) -> bool;
    fn set_approval_for_all(operator: ContractAddress, approved: bool);
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Array<felt252>
    );
    fn safe_batch_transfer_from(
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>,
        data: Array<felt252>
    );
    // IERC1155MetadataURI
    fn uri(id: u256) -> felt252;
}

#[abi]
trait IERC1155Receiver {
    fn onERC1155Received(
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Array<felt252>
    ) -> u32;
    fn onERC1155BatchReceived(
        operator: ContractAddress,
        from: ContractAddress,
        ids: Array<u256>,
        values: Array<u256>,
        data: Array<felt252>
    ) -> u32;
}

#[contract]
mod ERC1155 {
    // OZ modules
    use openzeppelin::account;
    use openzeppelin::introspection::erc165;
    use openzeppelin::token::erc1155;

    // Dispatchers
    use openzeppelin::introspection::erc165::IERC165Dispatcher;
    use openzeppelin::introspection::erc165::IERC165DispatcherTrait;
    use super::IERC1155ReceiverDispatcher;
    use super::IERC1155ReceiverDispatcherTrait;

    // Other
    use super::ArrayTrait;
    use super::ContractAddress;
    use starknet::contract_address_const;
    use starknet::ContractAddressZeroable;
    use starknet::get_caller_address;
    use integer::u256_from_felt252;
    use option::OptionTrait;
    use zeroable::Zeroable;

    struct Storage {
        _balances: LegacyMap<(u256, ContractAddress), u256>,
        _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        _uri: felt252,
    }

    #[event]
    fn TransferSingle(
        operator: ContractAddress, from: ContractAddress, to: ContractAddress, id: u256, value: u256
    ) {}

    #[event]
    fn TransferBatch(
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        values: Array<u256>
    ) {}

    #[event]
    fn ApprovalForAll(account: ContractAddress, operator: ContractAddress, approved: bool) {}

    #[constructor]
    fn constructor(uri: felt252) {
        initializer(uri);
    }

    impl ERC1155 of erc1155::IERC1155 {
        // IERC1155
        fn balance_of(account: ContractAddress, id: u256) -> u256 {
            _balances::read((id, account))
        }

        fn balance_of_batch(accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256> {
            _balance_of_batch_iter(accounts, ids, ArrayTrait::new())
        }

        fn is_approved_for_all(account: ContractAddress, operator: ContractAddress) -> bool {
            _operator_approvals::read((account, operator))
        }

        fn set_approval_for_all(operator: ContractAddress, approved: bool) {
            _set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn safe_transfer_from(
            from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Array<felt252>
        ) {
            let sender: ContractAddress = get_caller_address();
            assert(
                from == sender | ERC1155::is_approved_for_all(from, sender),
                'ERC1155: unauthorized caller'
            );
            _safe_transfer_from(from, to, id, amount, data);
        }

        fn safe_batch_transfer_from(
            from: ContractAddress,
            to: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>,
            data: Array<felt252>
        ) {
            let sender: ContractAddress = get_caller_address();
            assert(
                from == sender | ERC1155::is_approved_for_all(from, sender),
                'ERC1155: unauthorized caller'
            );
            _safe_batch_transfer_from(from, to, ids, amounts, data);
        }

        // IERC1155MetadataURI
        fn uri(id: u256) -> felt252 {
            _uri::read()
        }
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        erc165::ERC165Contract::supports_interface(interface_id)
    }

    #[view]
    fn balance_of(account: ContractAddress, id: u256) -> u256 {
        ERC1155::balance_of(account, id)
    }

    #[view]
    fn balance_of_batch(accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256> {
        ERC1155::balance_of_batch(accounts, ids)
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        ERC1155::is_approved_for_all(owner, operator)
    }

    #[view]
    fn uri(id: u256) -> felt252 {
        ERC1155::uri(id)
    }

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) {
        ERC1155::set_approval_for_all(operator, approved)
    }

    #[external]
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Array<felt252>
    ) {
        ERC1155::safe_transfer_from(from, to, id, amount, data)
    }

    #[external]
    fn safe_batch_transfer_from(
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>,
        data: Array<felt252>
    ) {
        ERC1155::safe_batch_transfer_from(from, to, ids, amounts, data)
    }

    #[internal]
    fn initializer(uri: felt252) {
        _set_uri(uri);
        erc165::ERC165Contract::register_interface(erc1155::IERC1155_ID);
        erc165::ERC165Contract::register_interface(erc1155::IERC1155_METADATA_ID);
    }

    #[internal]
    fn _set_approval_for_all(owner: ContractAddress, operator: ContractAddress, approved: bool) {
        assert(owner != operator, 'ERC1155: self approval');
        _operator_approvals::write((owner, operator), approved);
        ApprovalForAll(owner, operator, approved);
    }

    #[internal]
    fn _safe_transfer_from(
        from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Array<felt252>
    ) {
        let operator: ContractAddress = get_caller_address();
        assert(!to.is_zero(), 'ERC1155: invalid receiver');

        _balances::write((id, from), _balances::read((id, from)) - amount);
        _balances::write((id, to), _balances::read((id, to)) + amount);
        TransferSingle(operator, from, to, id, amount);

        _do_safe_transfer_acceptance_check(operator, from, to, id, amount, data);
    }

    #[internal]
    fn _safe_batch_transfer_from(
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>,
        data: Array<felt252>
    ) {}

    #[internal]
    fn _set_uri(uri: felt252) {
        _uri::write(uri)
    }

    #[private]
    fn _asSingletonArray(value: u256) -> Array<u256> {
        let mut array = ArrayTrait::new();
        array.append(value);
        array
    }

    #[private]
    fn _balance_of_batch_iter(
        mut accounts: Array<ContractAddress>, mut ids: Array<u256>, mut res: Array<u256>
    ) -> Array<u256> {
        match accounts.pop_front() {
            Option::Some(account) => {
                let id = ids.pop_front().expect('ERC1155 invalid array length');
                res.append(ERC1155::balance_of(account, id));
                _balance_of_batch_iter(accounts, ids, res)
            },
            Option::None(_) => {
                assert(ids.is_empty(), 'ERC1155 invalid array length');
                res
            }
        }
    }

    #[private]
    fn _do_safe_transfer_acceptance_check(
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
        data: Array<felt252>
    ) {
        if (IERC165Dispatcher {
            contract_address: to
        }.supports_interface(
            erc1155::IERC1155_RECEIVER_ID
        )) {
            assert(
                IERC1155ReceiverDispatcher {
                    contract_address: to
                }.onERC1155Received(
                    operator, from, id, amount, data
                ) == erc1155::ON_ERC1155_RECEIVED_SELECTOR,
                'ERC1155: receive fail'
            )
        } else {
            assert(
                IERC165Dispatcher {
                    contract_address: to
                }.supports_interface(account::ERC165_ACCOUNT_ID),
                'ERC1155: invalid receiver'
            )
        }
    }

    #[private]
    fn _do_safe_batch_transfer_acceptance_check(
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>,
        data: Array<felt252>
    ) {
        if (IERC165Dispatcher {
            contract_address: to
        }.supports_interface(
            erc1155::IERC1155_RECEIVER_ID
        )) {
            assert(
                IERC1155ReceiverDispatcher {
                    contract_address: to
                }.onERC1155BatchReceived(
                    operator, from, ids, amounts, data
                ) == erc1155::ON_ERC1155_BATCH_RECEIVED_SELECTOR,
                'ERC1155: batch receive fail'
            )
        } else {
            assert(
                IERC165Dispatcher {
                    contract_address: to
                }.supports_interface(account::ERC165_ACCOUNT_ID),
                'ERC1155: invalid receiver'
            )
        }
    }
}
