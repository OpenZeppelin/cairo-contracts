// SPDX-License-Identifier: MIT
#[starknet::contract]
mod vestingwalletmock {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::finance::vestingwallet::VestingWalletComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: VestingWalletComponent, storage: vestingwallet, event: vestingwalletevent);

    #[abi(embed_v0)]
    impl VestingWalletImpl =
        VestingWalletComponent::VestingWalletImpl<ContractState>;
    impl VestingWalletInternalImpl = VestingWalletComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        vestingwallet: VestingWalletComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        vestingwalletevent: VestingWalletComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        beneficiary: ContractAddress,
        vesting_start_time: u64,
        vesting_duration: u64,
    ) {
        self.vestingwallet.initializer(beneficiary, vesting_start_time, vesting_duration);
    }
}


#[starknet::contract]
mod vestingwalletcliffmock {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::finance::vestingwallet::VestingWalletCliffComponent;
    use openzeppelin::finance::vestingwallet::VestingWalletComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: VestingWalletComponent, storage: vestingwallet, event: vestingwalletevent);
    component!(
        path: VestingWalletCliffComponent,
        storage: vestingwalletcliff,
        event: vestingwalletcliffevent
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl VestingWalletImpl =
        VestingWalletComponent::VestingWalletImpl<ContractState>;
    impl VestingWalletInternalImpl = VestingWalletComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl VestingWalletCliffImpl =
        VestingWalletCliffComponent::VestingWalletCliffImpl<ContractState>;
    impl VestingWalletCliffInternalImpl = VestingWalletCliffComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        vestingwallet: VestingWalletComponent::Storage,
        #[substorage(v0)]
        vestingwalletcliff: VestingWalletCliffComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        vestingwalletevent: VestingWalletComponent::Event,
        #[flat]
        vestingwalletcliffevent: VestingWalletCliffComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        beneficiary: ContractAddress,
        vesting_start_time: u64,
        vesting_duration: u64,
        vesting_cliff: u64,
    ) {
        self
            .vestingwalletcliff
            .initializer(beneficiary, vesting_start_time, vesting_duration, vesting_cliff);
    }
}
