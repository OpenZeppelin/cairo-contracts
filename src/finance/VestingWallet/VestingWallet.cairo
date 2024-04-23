// SPDX-License-Identifier: MIT
#[starknet::component]
mod VestingWallet{

    use starknet::{ContractAddress, get_contract_address, get_timestamp};
    use starknet::contract_address::contract_address_const;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        start: u64,
        duration: u64,
        erc20released: LegacyMap<ContractAddress, u256>
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ERC20Released: ERC20Released
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    struct ERC20Released {
        token: ContractAddress,
        amount: u256
    }

    #[embeddable_as(VestingWalletImpl)]
    impl VestingWallet<
        TContractState, +HasComponent<TContractState>,
    > of interface::IVestingWallet<ComponentState<TContractState>> {
        fn get_start(
            self:  ComponentState<TContractState>
        ) -> u256 {
            self.start.read().into()
        }

        fn get_duration(
            self:  ComponentState<TContractState>
        ) -> u256 {
            self.duration.read().into()
        }

        fn get_end(
            self:  ComponentState<TContractState>
        ) -> u256 {
            self.start.read().into() + self.duration.read().into()
        }

        fn get_erc20_released(
            self:  ComponentState<TContractState>,
            token: ContractAddress
        ) -> u256 {
            self.erc20released.read(token)
        }

        fn get_erc20_releasable(
            self:  ComponentState<TContractState>,
            token: ContractAddress
        ) -> u256 {
            return self.vestedAmount(token, get_timestamp().into()) - self.erc20released.read(token);
        }

        fn release_erc20_token(ref self:  ComponentState<TContractState>, token: ContractAddress) -> bool {
            let releasableAmount = self.get_erc20_releasable(token);
            if(releasableAmount == 0) {
                return false;
            }
            self.erc20released.write(token, self.erc20released.read(token) + releasableAmount);
            self.emit(ERC20Released { token, amount: releasableAmount });
            return IERC20Dispatcher { contract_address: token}.transfer(self.ownable.read(), releasableAmount);
        }

        fn vestedAmount(ref self:  ComponentState<TContractState>, token: ContractAddress, timestamp: u64) ->  {
            let tokenAmount = IERC20Dispatcher { contract_address: token}.balance_of(get_contract_address());

            self._vestingSchedule(tokenAmount + self.erc20released.read(token), timestamp);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self:  ComponentState<TContractState>,
            beneficiary: ContractAddress
        ) {
            self.ownable.initializer(beneficiary);
            self.start.write(_start);
            self.duration.write(_duration);
        }

        fn _vestingSchedule(self: ComponentState<TContractState>,totalAllocation: u256, timestamp: u64) -> u256  {
            if(timestamp < self.start.read()) {
                return 0;
            }else if(timestamp >= self.start.read() + self.duration.read()) {
                return totalAllocation;
            }else {
                return totalAllocation * (timestamp - self.start.read()) / self.duration.read();
            }
        }
    }

}