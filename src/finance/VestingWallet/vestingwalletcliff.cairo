// SPDX-License-Identifier: MIT
#[starknet::component]
mod VestingWalletCliffcomponent{

    use starknet::{ContractAddress, get_contract_address, get_block_timestamp};
    use starknet::contract_address::contract_address_const;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::finance::vestingwallet::interface;
    use openzeppelin::finance::vestingwallet::VestingWalletcomponent;

    

    #[storage]
    struct Storage {
        #[substorage(v0)]
        cliff: u64,
    }

    mod Errors {
        const InvalidCliffDuration: felt252 = 'InvalidCliffDuration';
    }

    

    #[embeddable_as(VestingWalletCliffImpl)]
    impl VestingWalletCliff<
        TContractState, +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        impl VestingWallet: VestingWalletcomponent::HasComponent<TContractState>,
    > of interface::IVestingWalletCliff<ComponentState<TContractState>> {
        fn get_cliff(self: @ComponentState<TContractState>) -> u64 {
            return self.cliff.read();
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        impl VestingWallet: VestingWalletcomponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self:  ComponentState<TContractState>,
            beneficiary: ContractAddress,
            _start: u64,
            _duration: u64,
            _cliff: u64,
        ) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.Ownable_owner.write(beneficiary);
            let mut vestingwallet = get_dep_component_mut!(ref self, VestingWallet);
            vestingwallet.start.write(_start);
            vestingwallet.duration.write(_duration);
            self.cliff.write(_cliff);
        }

        fn _vestingSchedule(self: @ComponentState<TContractState>, totalAllocation: u256, timestamp: u64) -> u256  {
            let mut vestingwallet = get_dep_component!(self, VestingWallet);
            if(timestamp < vestingwallet.start.read()) {
                return 0;
            }else if(timestamp >= vestingwallet.start.read() + vestingwallet.duration.read()) {
                return totalAllocation;
            }else {
                return totalAllocation * (timestamp - vestingwallet.start.read().into()).into() / vestingwallet.duration.read().into();
            }
        }
    }

}