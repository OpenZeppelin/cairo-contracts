#[starknet::contract]
pub(crate) mod DualCaseERC6909Mock {
    use openzeppelin::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};
    use starknet::ContractAddress;

    /// Component
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    /// ABI of Components
    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909CamelOnlyImpl = ERC6909Component::ERC6909CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyImpl = ERC6909Component::ERC6909TokenSupplyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl = ERC6909Component::ERC6909ContentURIImpl<ContractState>;

    /// Internal logic
    impl InternalImpl = ERC6909Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
        self.erc6909._set_contract_uri("URI");
    }
}

#[starknet::contract]
pub(crate) mod SnakeERC6909Mock {
    use openzeppelin::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    /// ABI of Components
    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyImpl = ERC6909Component::ERC6909TokenSupplyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl = ERC6909Component::ERC6909ContentURIImpl<ContractState>;

    /// Internal logic
    impl InternalImpl = ERC6909Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
    }
}

#[starknet::contract]
pub(crate) mod CamelERC6909Mock {
    use openzeppelin::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    /// ABI of Components
    #[abi(embed_v0)]
    impl ERC6909CamelOnlyImpl = ERC6909Component::ERC6909CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyCamelImpl = ERC6909Component::ERC6909TokenSupplyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURICamelImpl = ERC6909Component::ERC6909ContentURICamelImpl<ContractState>;


    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    impl InternalImpl = ERC6909Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress, id: u256
        ) -> u256 {
            self.erc6909.allowance(owner, spender, id)
        }

        #[external(v0)]
        fn transfer(
            ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256
        ) -> bool {
            self.erc6909.transfer(receiver, id, amount)
        }

        #[external(v0)]
        fn approve(
            ref self: ContractState, spender: ContractAddress, id: u256, amount: u256
        ) -> bool {
            self.erc6909.approve(spender, id, amount)
        }
    }
}

/// Although these modules are designed to panic, functions
/// still need a valid return value. We chose:
///
/// 3 for felt252, u8, and u256
/// zero for ContractAddress
/// false for bool
#[starknet::contract]
pub(crate) mod SnakeERC6909Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn balance_of(self: @ContractState, owner: ContractAddress, id: u256) -> u256 {
            panic!("Some error");
            3
        }

        #[external(v0)]
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress, id: u256
        ) -> u256 {
            panic!("Some error");
            3
        }

        #[external(v0)]
        fn is_operator(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn transfer(
            ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn approve(
            ref self: ContractState, spender: ContractAddress, id: u256, amount: u256
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn set_operator(ref self: ContractState, spender: ContractAddress, approved: bool) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            panic!("Some error");
            false
        }
    }
}

#[starknet::contract]
pub(crate) mod CamelERC6909Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn balanceOf(self: @ContractState, owner: ContractAddress, id: u256) -> u256 {
            panic!("Some error");
            3
        }

        #[external(v0)]
        fn isOperator(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn setOperator(ref self: ContractState, spender: ContractAddress, approved: bool) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn supportsInterface(self: @ContractState, interface_id: felt252) -> bool {
            panic!("Some error");
            false
        }
    }
}
