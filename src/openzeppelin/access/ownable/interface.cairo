use starknet::ContractAddress;

#[starknet::interface]
trait IOwnable<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}

#[starknet::interface]
trait IOwnableCamel<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn transferOwnership(ref self: TContractState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TContractState);
}
