use starknet::ContractAddress;

const IACCESSCONTROL_ID: u32 = 0x7965db0b_u32;

#[abi]
trait IAccessControl {
    #[view]
    fn has_role(role: felt252, account: ContractAddress) -> bool;
    #[view]
    fn get_role_admin(role: felt252) -> felt252;
    #[external]
    fn grant_role(role: felt252, account: ContractAddress);
    #[external]
    fn revoke_role(role: felt252, account: ContractAddress);
    #[external]
    fn renounce_role(role: felt252, account: ContractAddress);
}

#[abi]
trait IAccessControlCamel {
    #[view]
    fn hasRole(role: felt252, account: ContractAddress) -> bool;
    #[view]
    fn getRoleAdmin(role: felt252) -> felt252;
    #[external]
    fn grantRole(role: felt252, account: ContractAddress);
    #[external]
    fn revokeRole(role: felt252, account: ContractAddress);
    #[external]
    fn renounceRole(role: felt252, account: ContractAddress);
}
