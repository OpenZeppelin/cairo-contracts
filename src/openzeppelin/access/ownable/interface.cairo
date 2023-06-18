use starknet::ContractAddress;

#[abi]
trait IOwnable {
    #[view]
    fn owner() -> ContractAddress;
    #[external]
    fn transfer_ownership(new_owner: ContractAddress);
    #[external]
    fn renounce_ownership();
}

#[abi]
trait IOwnableCamel {
    #[view]
    fn owner() -> ContractAddress;
    #[external]
    fn transferOwnership(newOwner: ContractAddress);
    #[external]
    fn renounceOwnership();
}
