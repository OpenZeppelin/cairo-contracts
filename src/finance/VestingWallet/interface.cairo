use starknet::ContractAddress;

/// Common interface for VestingWallet contracts.
#[starknet::interface]
trait IVestingWallet<TState> {
   fn get_start(self: @TState) -> u256;
   fn get_duration(self: @TState) -> u256;
   fn get_end(self: @TState) -> u256;
   fn get_erc20_released(self: @TState, token: ContractAddress) -> u256;
   fn get_erc20_releasable(self: @TState, token: ContractAddress) -> u256;
   fn release_erc20_token(self: @TState, token: ContractAddress) -> bool;
   fn vestedAmount(self: @TState, token: ContractAddress, Timestamp: u64) -> u256;
}
