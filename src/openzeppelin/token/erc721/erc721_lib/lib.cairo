use array::ArrayTrait;

#[abi]
trait IERC721Receiver {
    fn onERC721Received(operator: felt, from_: felt, token_id: u256, data: Array::<felt>) -> felt;
}

#[contract]
mod ERC721Library {
    use starknet::get_caller_address;

    const IERC721_RECEIVER_ID: felt = 0x150b7a02;

    struct Storage {
        _name: felt,
        _symbol: felt,
        _balances: LegacyMap::<felt, u256>,
        _owners: LegacyMap::<u256, felt>,
        _token_approvals: LegacyMap::<u256, felt>,
        _operator_approvals: LegacyMap::<(felt, felt), bool>,
        _token_uri: LegacyMap::<u256, felt>,
    }

    #[event]
    fn Transfer(from_: felt, to: felt, token_id: u256) {}

    #[event]
    fn Approval(owner: felt, spender: felt, token_id: u256) {}

    #[event]
    fn ApprovalForAll(owner: felt, operator: felt, approved: bool) {}

    fn initializer(name: felt, symbol: felt) {
        _name::write(name);
        _symbol::write(symbol);
    }

    fn supports_interface(interface_id: u32) -> bool {
        // TODO add ERC165
        true
    }

    fn name() -> felt {
        _name::read()
    }

    fn symbol() -> felt {
        _symbol::read()
    }

    fn balance_of(account: felt) -> u256 {
        assert(account != 0, 'ERC721: balance query for the zero address');
        _balances::read(account)
    }

    fn owner_of(token_id: u256) -> felt {
        let owner = _owners::read(token_id);
        assert(owner != 0, 'ERC721: owner query for nonexistent token');
        owner
    }

    fn token_uri(token_id: u256) -> felt {
        let _exists = exists(token_id);
        assert(_exists, 'ERC721_Metadata: URI query for nonexistent token');
        _token_uri::read(token_id)
    }

    fn get_approved(token_id: u256) -> felt {
        let _exists = exists(token_id);
        assert(_exists, 'ERC721: approved query for nonexistent token');
        _token_approvals::read(token_id)
    }

    fn is_approved_for_all(owner: felt, operator: felt) -> bool {
        _operator_approvals::read((owner, operator))
    }

    fn approve(to: felt, token_id: u256) {
        let caller = get_caller_address();
        assert(caller != 0, 'ERC721: cannot approve from the zero address');

        let owner = owner_of(token_id);
        assert(owner != to, 'ERC721: approval to current owner');
        assert(caller == owner | is_approved_for_all(owner, caller), 'ERC721: approve caller is not owner nor approved for all');
        _approve(to, token_id);
    }

    fn set_approval_for_all(operator: felt, approved: bool) {
        let caller = get_caller_address();
        assert(operator != 0, 'ERC721: operator is the zero address');
        assert(caller != 0, 'ERC721: caller is the zero address');
        assert(operator != caller, 'ERC721: approve to caller');
        _operator_approvals::write((caller, operator), approved);
        ApprovalForAll(caller, operator, approved);
    }

    fn transfer_from(from_: felt, to: felt, token_id: u256) {
        let caller = get_caller_address();
        assert(caller != 0, 'ERC721: caller is the zero address');
        assert(_is_approved_or_owner(caller, token_id), 'ERC721: caller is not approved');
        _transfer(from_, to, token_id);
    }

    fn safe_transfer_from(from_: felt, to: felt, token_id: u256, data: Array::<felt>) {
        let caller = get_caller_address();
        assert(caller != 0, 'ERC721: caller is the zero address');
        assert(_is_approved_or_owner(caller, token_id), 'ERC721: caller is not approved');
        _safe_transfer(from_, to, token_id, data);
    }

    fn exists(token_id: u256) -> bool {
        let _exists = _owners::read(token_id);
        match _exists {
            0 => false,
            _ => true
        }
    }

    fn assert_only_token_owner(token_id: u256) {
        let caller  = get_caller_address();
        let owner = owner_of(token_id);
        assert(caller == owner, 'ERC721: caller is not the token owner');
    }

    fn _approve(to: felt, token_id: u256) {
        _token_approvals::write(token_id, to);
        let owner = owner_of(token_id);
        Approval(owner, to, token_id);
    }

    fn _is_approved_or_owner(spender: felt, token_id: u256) -> bool {
        let owner = owner_of(token_id);
        spender == owner | is_approved_for_all(owner, spender) | get_approved(token_id) == spender
    }

    fn _transfer(from_: felt, to: felt, token_id: u256) {
        assert(owner_of(token_id) == from_, 'ERC721: transfer from incorrect owner');
        assert(to != 0, 'ERC721: cannot transfer to the zero address');
        _token_approvals::write(token_id, 0);
        _balances::write(from_, _balances::read(from_) - u256_from_felt(1));
        _balances::write(to, _balances::read(to) + u256_from_felt(1));
        _owners::write(token_id, to);
        Transfer(from_, to, token_id);
    }

    fn _safe_transfer(from_: felt, to: felt, token_id: u256, data: Array::<felt>) {
        _transfer(from_, to, token_id);
        let success = _check_onERC721Received(from_, to, token_id, data);
        assert(success, 'ERC721: transfer to non ERC721Receiver implementer');
    }

    fn _mint(to: felt, token_id: u256) {
        assert(to != 0, 'ERC721: cannot mint to the zero address');
        assert(!exists(token_id), 'ERC721: token already minted');
        _balances::write(to, (_balances::read(to) + u256_from_felt(1)));
        _owners::write(token_id, to);
        Transfer(0, to, token_id);
    }

    fn _safe_mint(to: felt, token_id: u256, data: Array::<felt>) {
        _mint(to, token_id);
        let success = _check_onERC721Received(0, to, token_id, data);
        assert(success, 'ERC721: transfer to non ERC721Receiver implementer');
    }

    fn _burn(token_id: u256) {
        let owner = owner_of(token_id);
        _token_approvals::write(token_id, 0);
        _balances::write(owner, (_balances::read(owner) - u256_from_felt(1)));
        _owners::write(token_id, 0);
        Transfer(owner, 0, token_id);
    }

    fn _set_token_uri(token_id: u256, token_uri: felt) {
        assert(exists(token_id), 'ERC721_Metadata: set token URI for nonexistent token');
        _token_uri::write(token_id, token_uri);
    }

    fn _check_onERC721Received(from_: felt, to: felt, token_id: u256, data: Array::<felt>) -> bool {
        // Plugin diagnostic: Const generic inference not yet supported. (re: address expression)
        let address = starknet::contract_address_const::<17>();
        let selector = super::IERC721ReceiverDispatcher::onERC721Received(address, from_, to, token_id, data);
        if selector == IERC721_RECEIVER_ID {
            return true;
        }
        // TODO add account check
        return false;
    }
}
