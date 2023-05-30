use starknet::ContractAddress;

#[abi]
trait ERC721ABI {
    // case agnostic
    #[view]
    fn name() -> felt252;
    #[view]
    fn symbol() -> felt252;
    #[external]
    fn approve(to: ContractAddress, token_id: u256);
    // snake_case
    #[view]
    fn balance_of(account: ContractAddress) -> u256;
    #[view]
    fn owner_of(token_id: u256) -> ContractAddress;
    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256);
    #[external]
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    );
    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool);
    #[view]
    fn get_approved(token_id: u256) -> ContractAddress;
    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool;
    #[view]
    fn token_uri(token_id: u256) -> felt252;
    // camelCase
    #[view]
    fn balanceOf(account: ContractAddress) -> u256;
    #[view]
    fn ownerOf(tokenId: u256) -> ContractAddress;
    #[external]
    fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256);
    #[external]
    fn safeTransferFrom(
        from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
    );
    #[external]
    fn setApprovalForAll(operator: ContractAddress, approved: bool);
    #[view]
    fn getApproved(tokenId: u256) -> ContractAddress;
    #[view]
    fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool;
    #[view]
    fn tokenUri(tokenId: u256) -> felt252;
}

#[contract]
mod ERC721 {
    // OZ modules
    use openzeppelin::account;
    use openzeppelin::introspection::erc165;
    use openzeppelin::token::erc721;

    // Dispatchers
    use openzeppelin::introspection::erc165::IERC165Dispatcher;
    use openzeppelin::introspection::erc165::IERC165DispatcherTrait;
    use super::super::interface::IERC721ReceiverABIDispatcher;
    use super::super::interface::IERC721ReceiverABIDispatcherTrait;

    // Other
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::SpanTrait;
    use traits::Into;
    use openzeppelin::utils::serde::SpanSerde;

    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _owners: LegacyMap<u256, ContractAddress>,
        _balances: LegacyMap<ContractAddress, u256>,
        _token_approvals: LegacyMap<u256, ContractAddress>,
        _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        _token_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, approved: ContractAddress, token_id: u256) {}

    #[event]
    fn ApprovalForAll(owner: ContractAddress, operator: ContractAddress, approved: bool) {}

    #[constructor]
    fn constructor(name: felt252, symbol: felt252) {
        initializer(name, symbol);
    }

    impl ERC721Impl of erc721::interface::IERC721 {
        fn name() -> felt252 {
            _name::read()
        }

        fn symbol() -> felt252 {
            _symbol::read()
        }

        fn token_uri(token_id: u256) -> felt252 {
            assert(_exists(token_id), 'ERC721: invalid token ID');
            _token_uri::read(token_id)
        }

        fn balance_of(account: ContractAddress) -> u256 {
            assert(!account.is_zero(), 'ERC721: invalid account');
            _balances::read(account)
        }

        fn owner_of(token_id: u256) -> ContractAddress {
            _owner_of(token_id)
        }

        fn get_approved(token_id: u256) -> ContractAddress {
            assert(_exists(token_id), 'ERC721: invalid token ID');
            _token_approvals::read(token_id)
        }

        fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
            _operator_approvals::read((owner, operator))
        }

        fn approve(to: ContractAddress, token_id: u256) {
            let owner = _owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller | is_approved_for_all(owner, caller), 'ERC721: unauthorized caller'
            );
            _approve(to, token_id);
        }

        fn set_approval_for_all(operator: ContractAddress, approved: bool) {
            _set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256) {
            assert(
                _is_approved_or_owner(get_caller_address(), token_id), 'ERC721: unauthorized caller'
            );
            _transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
        ) {
            assert(
                _is_approved_or_owner(get_caller_address(), token_id), 'ERC721: unauthorized caller'
            );
            _safe_transfer(from, to, token_id, data);
        }
    }

    impl ERC721CamelImpl of erc721::interface::IERC721Camel {
        fn name() -> felt252 {
            ERC721Impl::name()
        }

        fn symbol() -> felt252 {
            ERC721Impl::symbol()
        }

        fn tokenUri(tokenId: u256) -> felt252 {
            ERC721Impl::token_uri(tokenId)
        }

        fn balanceOf(account: ContractAddress) -> u256 {
            ERC721Impl::balance_of(account)
        }

        fn ownerOf(tokenId: u256) -> ContractAddress {
            ERC721Impl::owner_of(tokenId)
        }

        fn approve(to: ContractAddress, tokenId: u256) {
            ERC721Impl::approve(to, tokenId)
        }

        fn getApproved(tokenId: u256) -> ContractAddress {
            ERC721Impl::get_approved(tokenId)
        }

        fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool {
            ERC721Impl::is_approved_for_all(owner, operator)
        }

        fn setApprovalForAll(operator: ContractAddress, approved: bool) {
            ERC721Impl::set_approval_for_all(operator, approved)
        }

        fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256) {
            ERC721Impl::transfer_from(from, to, tokenId)
        }

        fn safeTransferFrom(
            from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
        ) {
            ERC721Impl::safe_transfer_from(from, to, tokenId, data)
        }
    }

    // View

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        erc165::ERC165::supports_interface(interface_id)
    }

    #[view]
    fn supportsInterface(interfaceId: u32) -> bool {
        erc165::ERC165::supports_interface(interfaceId)
    }

    #[view]
    fn name() -> felt252 {
        ERC721Impl::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC721Impl::symbol()
    }

    #[view]
    fn token_uri(token_id: u256) -> felt252 {
        ERC721Impl::token_uri(token_id)
    }

    #[view]
    fn tokenUri(tokenId: u256) -> felt252 {
        ERC721CamelImpl::tokenUri(tokenId)
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC721Impl::balance_of(account)
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        ERC721CamelImpl::balanceOf(account)
    }

    #[view]
    fn owner_of(token_id: u256) -> ContractAddress {
        ERC721Impl::owner_of(token_id)
    }

    #[view]
    fn ownerOf(tokenId: u256) -> ContractAddress {
        ERC721CamelImpl::ownerOf(tokenId)
    }

    #[view]
    fn get_approved(token_id: u256) -> ContractAddress {
        ERC721Impl::get_approved(token_id)
    }

    #[view]
    fn getApproved(tokenId: u256) -> ContractAddress {
        ERC721CamelImpl::getApproved(tokenId)
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        ERC721Impl::is_approved_for_all(owner, operator)
    }

    #[view]
    fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool {
        ERC721CamelImpl::isApprovedForAll(owner, operator)
    }

    // External

    #[external]
    fn approve(to: ContractAddress, token_id: u256) {
        ERC721Impl::approve(to, token_id)
    }

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) {
        ERC721Impl::set_approval_for_all(operator, approved)
    }

    #[external]
    fn setApprovalForAll(operator: ContractAddress, approved: bool) {
        ERC721CamelImpl::setApprovalForAll(operator, approved)
    }

    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256) {
        ERC721Impl::transfer_from(from, to, token_id)
    }

    #[external]
    fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256) {
        ERC721CamelImpl::transferFrom(from, to, tokenId)
    }

    #[external]
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) {
        ERC721Impl::safe_transfer_from(from, to, token_id, data)
    }

    #[external]
    fn safeTransferFrom(
        from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
    ) {
        ERC721CamelImpl::safeTransferFrom(from, to, tokenId, data)
    }

    // Internal

    #[internal]
    fn initializer(name_: felt252, symbol_: felt252) {
        _name::write(name_);
        _symbol::write(symbol_);
        erc165::ERC165::register_interface(erc721::interface::IERC721_ID);
        erc165::ERC165::register_interface(erc721::interface::IERC721_METADATA_ID);
    }

    #[internal]
    fn _owner_of(token_id: u256) -> ContractAddress {
        let owner = _owners::read(token_id);
        match owner.is_zero() {
            bool::False(()) => owner,
            bool::True(()) => panic_with_felt252('ERC721: invalid token ID')
        }
    }

    #[internal]
    fn _exists(token_id: u256) -> bool {
        !_owners::read(token_id).is_zero()
    }

    #[internal]
    fn _is_approved_or_owner(spender: ContractAddress, token_id: u256) -> bool {
        let owner = _owner_of(token_id);
        owner == spender | is_approved_for_all(owner, spender) | spender == get_approved(token_id)
    }

    #[internal]
    fn _approve(to: ContractAddress, token_id: u256) {
        let owner = _owner_of(token_id);
        assert(owner != to, 'ERC721: approval to owner');
        _token_approvals::write(token_id, to);
        Approval(owner, to, token_id);
    }

    #[internal]
    fn _set_approval_for_all(owner: ContractAddress, operator: ContractAddress, approved: bool) {
        assert(owner != operator, 'ERC721: self approval');
        _operator_approvals::write((owner, operator), approved);
        ApprovalForAll(owner, operator, approved);
    }

    #[internal]
    fn _mint(to: ContractAddress, token_id: u256) {
        assert(!to.is_zero(), 'ERC721: invalid receiver');
        assert(!_exists(token_id), 'ERC721: token already minted');

        // Update balances
        _balances::write(to, _balances::read(to) + 1.into());

        // Update token_id owner
        _owners::write(token_id, to);

        // Emit event
        Transfer(Zeroable::zero(), to, token_id);
    }

    #[internal]
    fn _transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {
        assert(!to.is_zero(), 'ERC721: invalid receiver');
        let owner = _owner_of(token_id);
        assert(from == owner, 'ERC721: wrong sender');

        // Implicit clear approvals, no need to emit an event
        _token_approvals::write(token_id, Zeroable::zero());

        // Update balances
        _balances::write(from, _balances::read(from) - 1.into());
        _balances::write(to, _balances::read(to) + 1.into());

        // Update token_id owner
        _owners::write(token_id, to);

        // Emit event
        Transfer(from, to, token_id);
    }

    #[internal]
    fn _burn(token_id: u256) {
        let owner = _owner_of(token_id);

        // Implicit clear approvals, no need to emit an event
        _token_approvals::write(token_id, Zeroable::zero());

        // Update balances
        _balances::write(owner, _balances::read(owner) - 1.into());

        // Delete owner
        _owners::write(token_id, Zeroable::zero());

        // Emit event
        Transfer(owner, Zeroable::zero(), token_id);
    }

    #[internal]
    fn _safe_mint(to: ContractAddress, token_id: u256, data: Span<felt252>) {
        _mint(to, token_id);
        assert(
            _check_on_erc721_received(Zeroable::zero(), to, token_id, data),
            'ERC721: safe mint failed'
        );
    }

    #[internal]
    fn _safe_transfer(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) {
        _transfer(from, to, token_id);
        assert(_check_on_erc721_received(from, to, token_id, data), 'ERC721: safe transfer failed');
    }

    #[internal]
    fn _set_token_uri(token_id: u256, token_uri: felt252) {
        assert(_exists(token_id), 'ERC721: invalid token ID');
        _token_uri::write(token_id, token_uri)
    }

    #[private]
    fn _check_on_erc721_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> bool {
        if (IERC165Dispatcher {
            contract_address: to
        }.supports_interface(erc721::interface::IERC721_RECEIVER_ID)) {
            // todo add casing fallback mechanism
            IERC721ReceiverABIDispatcher {
                contract_address: to
            }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == erc721::interface::IERC721_RECEIVER_ID
        } else {
            IERC165Dispatcher {
                contract_address: to
            }.supports_interface(account::interface::IACCOUNT_ID)
        }
    }
}
