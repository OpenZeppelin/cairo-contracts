// SPDX-License-Identifier: MIT
#[starknet::component]
mod VestingWalletcomponent {
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as Ownable
    };
    use openzeppelin::finance::vestingwallet::interface;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::contract_address::contract_address_const;
    use starknet::{ContractAddress, get_contract_address, get_block_timestamp};

    #[storage]
    struct Storage {
        #[substorage(v0)]
        start: u64,
        duration: u64,
        erc20released: LegacyMap<ContractAddress, u256>
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ERC20Released: ERC20Released
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ERC20Released {
        token: ContractAddress,
        amount: u256
    }

    #[embeddable_as(VestingWalletImpl)]
    impl VestingWallet<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
    > of interface::IVestingWallet<ComponentState<TContractState>> {
        fn get_start(self: @ComponentState<TContractState>) -> u256 {
            self.start.read().into()
        }

        fn get_duration(self: @ComponentState<TContractState>) -> u256 {
            self.duration.read().into()
        }

        fn get_end(self: @ComponentState<TContractState>) -> u256 {
            self.start.read().into() + self.duration.read().into()
        }

        fn get_erc20_released(
            self: @ComponentState<TContractState>, token: ContractAddress
        ) -> u256 {
            self.erc20released.read(token)
        }

        fn get_erc20_releasable(
            self: @ComponentState<TContractState>, token: ContractAddress
        ) -> u256 {
            return self.vestedAmount(token, get_block_timestamp().into())
                - self.erc20released.read(token);
        }

        fn release_erc20_token(
            ref self: ComponentState<TContractState>, token: ContractAddress
        ) -> bool {
            let releasableAmount = self.get_erc20_releasable(token);
            if (releasableAmount == 0) {
                return false;
            }
            self.erc20released.write(token, self.erc20released.read(token) + releasableAmount);
            self.emit(ERC20Released { token, amount: releasableAmount });
            let ownable_comp = get_dep_component!(@self, Ownable);
            return IERC20Dispatcher { contract_address: token }
                .transfer(ownable_comp.Ownable_owner.read(), releasableAmount);
        }

        fn vestedAmount(
            self: @ComponentState<TContractState>, token: ContractAddress, timestamp: u64
        ) -> u256 {
            let tokenAmount = IERC20Dispatcher { contract_address: token }
                .balance_of(get_contract_address());
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            beneficiary: ContractAddress,
            _start: u64,
            _duration: u64
        ) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.initializer(beneficiary);
            self.start.write(_start);
            self.duration.write(_duration);
        }

        fn _vestingSchedule(
            self: @ComponentState<TContractState>, totalAllocation: u256, timestamp: u64
        ) -> u256 {
            if (timestamp < self.start.read()) {
                return 0;
            } else if (timestamp >= self.start.read() + self.duration.read()) {
                return totalAllocation;
            } else {
                return totalAllocation
                    * (timestamp - self.start.read().into()).into()
                    / self.duration.read().into();
            }
        }
    }
}
