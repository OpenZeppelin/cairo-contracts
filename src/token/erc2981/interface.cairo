use openzeppelin::token::erc2981::FeesRatio;
use starknet::ContractAddress;


pub const IERC2981_ID: felt252 = 0x2d3414e45a8700c29f119a54b9f11dca0e29e06ddcb214018fc37340e165ed6;

#[starknet::interface]
pub trait IERC2981<TState> {
    fn royalty_info(self: @TState, token_id: u256, sale_price: u256) -> (ContractAddress, u256);
}


#[starknet::interface]
pub trait IERC2981Setup<TState> {
    fn default_royalty(self: @TState) -> (ContractAddress, FeesRatio);
    fn set_default_royalty(ref self: TState, receiver: ContractAddress, fees_ratio: FeesRatio);

    fn token_royalty(self: @TState, token_id: u256) -> (ContractAddress, FeesRatio);
    fn set_token_royalty(
        ref self: TState, token_id: u256, receiver: ContractAddress, fees_ratio: FeesRatio
    );
}
