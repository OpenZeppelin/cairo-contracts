// SPDX-License-Identifier: MIT
use core::starknet::{ContractAddress};

/// # ERC6909 Component
///
/// The ERC6909 component provides an implementation of the Minimal Multi-Token standard authored by jtriley.eth
/// See https://eips.ethereum.org/EIPS/eip-6909.
#[starknet::component]
pub mod ERC6909Component {
    use core::integer::BoundedInt;
    use core::num::traits::Zero;
    use core::starknet::{ContractAddress, get_caller_address};
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::token::erc6909::interface;

    #[storage]
    struct Storage {
        ERC6909_name: LegacyMap<u256, ByteArray>,
        ERC6909_symbol: LegacyMap<u256, ByteArray>,
        ERC6909_decimals: LegacyMap<u256, u8>,
        ERC6909_balances: LegacyMap<(ContractAddress, u256), u256>,
        ERC6909_allowances: LegacyMap<(ContractAddress, ContractAddress, u256), u256>,
        ERC6909_operators: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC6909_total_supply: LegacyMap<u256, u256>,
        ERC6909_contract_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OperatorSet: OperatorSet
    }

    /// @notice The event emitted when a transfer occurs.
    /// @param caller The caller of the transfer.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Transfer {
        pub caller: ContractAddress,
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        #[key]
        pub id: u256,
        pub amount: u256,
    }

    /// @notice The event emitted when an approval occurs.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        #[key]
        pub id: u256,
        pub amount: u256
    }

    /// @notice The event emitted when an operator is set.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param approved The approval status.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct OperatorSet {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub approved: bool,
    }

    pub mod Errors {
        /// @dev Thrown when owner balance for id is insufficient.
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC6909: insufficient balance';
        /// @dev Thrown when spender allowance for id is insufficient.
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC6909: insufficient allowance';
        /// @dev Thrown when transfering from the zero address
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC6909: transfer from 0';
        /// @dev Thrown when transfering to the zero address
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC6909: transfer to 0';
        /// @dev Thrown when minting to the zero address
        pub const MINT_TO_ZERO: felt252 = 'ERC6909: mint to 0';
        /// @dev Thrown when burning from the zero address
        pub const BURN_FROM_ZERO: felt252 = 'ERC6909: burn from 0';
        /// @dev Thrown when approving from the zero address
        pub const APPROVE_FROM_ZERO: felt252 = 'ERC6909: approve from 0';
        /// @dev Thrown when approving to the zero address
        pub const APPROVE_TO_ZERO: felt252 = 'ERC6909: approve to 0';
    }

    /// Hooks
    pub trait ERC6909HooksTrait<TContractState> {
        fn before_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        );

        fn after_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        );
    }

    #[embeddable_as(ERC6909Impl)]
    impl ERC6909<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909<ComponentState<TContractState>> {
        /// @notice Owner balance of an id.
        /// @param owner The address of the owner.
        /// @param id The id of the token.
        /// @return The balance of the token.
        fn balance_of(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256
        ) -> u256 {
            self.ERC6909_balances.read((owner, id))
        }

        /// @notice Spender allowance of an id.
        /// @param owner The address of the owner.
        /// @param spender The address of the spender.
        /// @param id The id of the token.
        /// @return The allowance of the token.
        fn allowance(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256
        ) -> u256 {
            self.ERC6909_allowances.read((owner, spender, id))
        }

        /// @notice Checks if a spender is approved by an owner as an operator
        /// @param owner The address of the owner.
        /// @param spender The address of the spender.
        /// @return The approval status.
        fn is_operator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            self.ERC6909_operators.read((owner, spender))
        }

        /// @notice Transfers an amount of an id from the caller to a receiver.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transfer(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, caller, receiver, id, amount);
            true
        }

        /// @notice Transfers an amount of an id from a sender to a receiver.
        /// @param sender The address of the sender.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, id, amount);
            self._transfer(caller, sender, receiver, id, amount);
            true
        }

        /// @notice Approves an amount of an id to a spender.
        /// @param spender The address of the spender.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn approve(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, id, amount);
            true
        }

        /// @notice Sets or unsets a spender as an operator for the caller.
        /// @param spender The address of the spender.
        /// @param approved The approval status.
        fn set_operator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool
        ) -> bool {
            let caller = get_caller_address();
            self._set_operator(caller, spender, approved);
            true
        }

        /// @notice Checks if a contract implements an interface.
        /// @param interfaceId The interface identifier, as specified in ERC-165.
        /// @return True if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, false otherwise.
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            interface_id == interface::IERC6909_ID || interface_id == ISRC5_ID
        }
    }

    #[embeddable_as(ERC6909CamelOnlyImpl)]
    impl ERC6909CamelOnly<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909CamelOnly<ComponentState<TContractState>> {
        /// @notice Owner balance of an id.
        /// @param owner The address of the owner.
        /// @param id The id of the token.
        /// @return The balance of the token.
        fn balanceOf(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256
        ) -> u256 {
            ERC6909::balance_of(self, owner, id)
        }

        /// @notice Checks if a spender is approved by an owner as an operator
        /// @param owner The address of the owner.
        /// @param spender The address of the spender.
        /// @return The approval status.
        fn isOperator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            ERC6909::is_operator(self, owner, spender)
        }

        /// @notice Transfers an amount of an id from a sender to a receiver.
        /// @param sender The address of the sender.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::transfer_from(ref self, sender, receiver, id, amount)
        }

        /// @notice Sets or unsets a spender as an operator for the caller.
        /// @param spender The address of the spender.
        /// @param approved The approval status.
        fn setOperator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool
        ) -> bool {
            ERC6909::set_operator(ref self, spender, approved)
        }

        /// @notice Checks if a contract implements an interface.
        /// @param interfaceId The interface identifier, as specified in ERC-165.
        /// @return True if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, false otherwise.
        fn supportsInterface(self: @ComponentState<TContractState>, interface_id: felt252) -> bool {
            ERC6909::supports_interface(self, interface_id)
        }
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// @notice Name of a given token.
        /// @param id The id of the token.
        /// @return The name of the token.
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909_name.read(id)
        }

        /// @notice Symbol of a given token.
        /// @param id The id of the token.
        /// @return The symbol of the token.
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909_symbol.read(id)
        }

        /// @notice Decimals of a given token.
        /// @param id The id of the token.
        /// @return The decimals of the token.
        fn decimals(self: @ComponentState<TContractState>, id: u256) -> u8 {
            self.ERC6909_decimals.read(id)
        }
    }

    #[embeddable_as(ERC6909TokenSupplyImpl)]
    impl ERC6909TokenSupply<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909TokenSupply<ComponentState<TContractState>> {
        /// @notice Total supply of a token
        /// @param id The id of the token.
        /// @return The total supply of the token.
        fn total_supply(self: @ComponentState<TContractState>, id: u256) -> u256 {
            self.ERC6909_total_supply.read(id)
        }
    }

    #[embeddable_as(ERC6909TokenSupplyCamelImpl)]
    impl ERC6909TokenSupplyCamel<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909TokenSupplyCamel<ComponentState<TContractState>> {
        /// @notice Total supply of a token
        /// @param id The id of the token.
        /// @return The total supply of the token.
        fn totalSupply(self: @ComponentState<TContractState>, id: u256) -> u256 {
            ERC6909TokenSupply::total_supply(self, id)
        }
    }


    #[embeddable_as(ERC6909ContentURIImpl)]
    impl ERC6909ContentURI<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909ContentURI<ComponentState<TContractState>> {
        /// @notice The contract level URI.
        /// @return The URI of the contract.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909_contract_uri.read()
        }

        /// @notice Token level URI
        /// @param id The id of the token.
        /// @return The token level URI.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            let contract_uri = self.contract_uri();
            if contract_uri.len() != 0 {
                return "";
            } else {
                return format!("{}{}", contract_uri, id);
            }
        }
    }

    #[embeddable_as(ERC6909ContentURICamelImpl)]
    impl ERC6909ContentURICamel<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909ContentURICamel<ComponentState<TContractState>> {
        /// @notice Contract level URI
        /// @return uri The contract level URI.
        fn contractUri(self: @ComponentState<TContractState>) -> ByteArray {
            ERC6909ContentURI::contract_uri(self)
        }

        /// @notice Token level URI
        /// @param id The id of the token.
        /// @return The token level URI.
        fn tokenUri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            ERC6909ContentURI::token_uri(self, id)
        }
    }

    /// internal
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, impl Hooks: ERC6909HooksTrait<TContractState>
    > of InternalTrait<TContractState> {
        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn mint(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!receiver.is_zero(), Errors::MINT_TO_ZERO);
            self.update(get_caller_address(), Zero::zero(), receiver, id, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn burn(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self.update(get_caller_address(), account, Zero::zero(), id, amount);
        }

        /// Transfers an `amount` of tokens from `sender` to `receiver`, or alternatively mints (or burns) if `sender` (or `receiver`) is
        /// the zero address.
        ///
        /// Emits a `Transfer` event.
        fn update(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            sender: ContractAddress, // from
            receiver: ContractAddress, // to
            id: u256,
            amount: u256
        ) {
            Hooks::before_update(ref self, sender, receiver, id, amount);

            let zero_address = Zero::zero();
            if (sender == zero_address) {
                let total_supply = self.ERC6909_total_supply.read(id);
                self.ERC6909_total_supply.write(id, total_supply + amount);
            } else {
                let sender_balance = self.ERC6909_balances.read((sender, id));
                assert(sender_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.ERC6909_balances.write((sender, id), sender_balance - amount);
            }

            if (receiver == zero_address) {
                let total_supply = self.ERC6909_total_supply.read(id);
                self.ERC6909_total_supply.write(id, total_supply - amount);
            } else {
                let receiver_balance = self.ERC6909_balances.read((receiver, id));
                self.ERC6909_balances.write((receiver, id), receiver_balance + amount);
            }

            self.emit(Transfer { caller, sender, receiver, id, amount });

            Hooks::after_update(ref self, sender, receiver, id, amount);
        }

        /// Sets the base URI.
        fn _set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            self.ERC6909_contract_uri.write(contract_uri);
        }

        /// Sets the token name.
        fn _set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            self.ERC6909_name.write(id, name);
        }

        /// Sets the token symbol.
        fn _set_token_symbol(
            ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray
        ) {
            self.ERC6909_symbol.write(id, symbol);
        }

        /// Sets the token decimals.
        fn _set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            self.ERC6909_decimals.write(id, decimals);
        }

        /// @notice Sets or unsets a spender as an operator for the caller.
        /// @param owner The address of the owner.
        /// @param spender The address of the spender.
        /// @param approved The approval status.
        fn _set_operator(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            approved: bool
        ) {
            self.ERC6909_operators.write((owner, spender), approved);
            self.emit(OperatorSet { owner, spender, approved });
        }

        /// Updates `sender`s allowance for `spender`  and `id` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance or if spender is operator.
        fn _spend_allowance(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) {
            // In accordance with the transferFrom method, spenders with operator permission are not subject to 
            // allowance restrictions (https://eips.ethereum.org/EIPS/eip-6909).
            if sender != spender && !self.ERC6909_operators.read((sender, spender)) {
                let sender_allowance = self.ERC6909_allowances.read((sender, spender, id));
                assert(sender_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
                if sender_allowance != BoundedInt::max() {
                    self._approve(sender, spender, id, sender_allowance - amount)
                }
            }
        }

        /// Internal method that sets `amount` as the allowance of `spender` over the
        /// `owner`s tokens.
        ///
        /// Requirements:
        ///
        /// - `owner` is not the zero address.
        /// - `spender` is not the zero address.
        ///
        /// Emits an `Approval` event.
        fn _approve(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.ERC6909_allowances.write((owner, spender, id), amount);
            self.emit(Approval { owner, spender, id, amount });
        }

        /// Internal method that moves an `amount` of tokens from `sender` to `receiver`.
        ///
        /// Requirements:
        ///
        /// - `sender` is not the zero address.
        /// - `sender` must have at least a balance of `amount`.
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!receiver.is_zero(), Errors::TRANSFER_TO_ZERO);
            self.update(caller, sender, receiver, id, amount);
        }
    }

    #[embeddable_as(ERC6909MixinImpl)]
    impl ERC6909Mixin<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::ERC6909ABI<ComponentState<TContractState>> {
        //
        // ABI
        //

        fn balance_of(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256
        ) -> u256 {
            ERC6909::balance_of(self, owner, id)
        }

        fn allowance(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256
        ) -> u256 {
            ERC6909::allowance(self, owner, spender, id)
        }

        fn is_operator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            ERC6909::is_operator(self, owner, spender)
        }

        fn transfer(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::transfer(ref self, receiver, id, amount)
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::transfer_from(ref self, sender, receiver, id, amount)
        }

        fn approve(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::approve(ref self, spender, id, amount)
        }

        fn set_operator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool
        ) -> bool {
            ERC6909::set_operator(ref self, spender, approved)
        }

        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            ERC6909::supports_interface(self, interface_id)
        }

        // 
        // CamelCase
        //

        fn balanceOf(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256
        ) -> u256 {
            ERC6909::balance_of(self, owner, id)
        }

        fn isOperator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            ERC6909::is_operator(self, owner, spender)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::transfer_from(ref self, sender, receiver, id, amount)
        }

        fn setOperator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool
        ) -> bool {
            ERC6909::set_operator(ref self, spender, approved)
        }

        fn supportsInterface(self: @ComponentState<TContractState>, interfaceId: felt252) -> bool {
            ERC6909::supports_interface(self, interfaceId)
        }
    }
}

/// An empty implementation of the ERC6909 hooks to be used in basic ERC6909 preset contracts.
pub impl ERC6909HooksEmptyImpl<
    TContractState
> of ERC6909Component::ERC6909HooksTrait<TContractState> {
    fn before_update(
        ref self: ERC6909Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256
    ) {}

    fn after_update(
        ref self: ERC6909Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256
    ) {}
}
