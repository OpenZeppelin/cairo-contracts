#[starknet::contract]
mod Upgradeable {
    use starknet::ClassHash;
    use starknet::SyscallResult;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[generate_trait]
    impl InternalImpl of InternalState {
        fn _upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
