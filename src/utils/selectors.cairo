// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.1 (utils/selectors.cairo)

//
// AccessControl
//

const get_role_admin: felt252 = selector!("get_role_admin");
const getRoleAdmin: felt252 = selector!("getRoleAdmin");
const grant_role: felt252 = selector!("grant_role");
const grantRole: felt252 = selector!("grantRole");
const has_role: felt252 = selector!("has_role");
const hasRole: felt252 = selector!("hasRole");
const renounce_role: felt252 = selector!("renounce_role");
const renounceRole: felt252 = selector!("renounceRole");
const revoke_role: felt252 = selector!("revoke_role");
const revokeRole: felt252 = selector!("revokeRole");

//
// Ownable
//

const owner: felt252 = selector!("owner");
const transfer_ownership: felt252 = selector!("transfer_ownership");
const transferOwnership: felt252 = selector!("transferOwnership");
const renounce_ownership: felt252 = selector!("renounce_ownership");
const renounceOwnership: felt252 = selector!("renounceOwnership");

//
// ERC721
//

const name: felt252 = selector!("name");
const symbol: felt252 = selector!("symbol");
const token_uri: felt252 = selector!("token_uri");
const tokenURI: felt252 = selector!("tokenURI");
const balance_of: felt252 = selector!("balance_of");
const balanceOf: felt252 = selector!("balanceOf");
const owner_of: felt252 = selector!("owner_of");
const ownerOf: felt252 = selector!("ownerOf");
const get_approved: felt252 = selector!("get_approved");
const getApproved: felt252 = selector!("getApproved");
const is_approved_for_all: felt252 = selector!("is_approved_for_all");
const isApprovedForAll: felt252 = selector!("isApprovedForAll");
const approve: felt252 = selector!("approve");
const set_approval_for_all: felt252 = selector!("set_approval_for_all");
const setApprovalForAll: felt252 = selector!("setApprovalForAll");
const transfer_from: felt252 = selector!("transfer_from");
const transferFrom: felt252 = selector!("transferFrom");
const safe_transfer_from: felt252 = selector!("safe_transfer_from");
const safeTransferFrom: felt252 = selector!("safeTransferFrom");

//
// ERC721Receiver
//

const on_erc721_received: felt252 = selector!("on_erc721_received");
const onERC721Received: felt252 = selector!("onERC721Received");

//
// ERC20
//

// The following ERC20 selectors are already defined in ERC721 above:
// name, symbol, balance_of, balanceOf, transfer_from, transferFrom, approve
const decimals: felt252 = selector!("decimals");
const total_supply: felt252 = selector!("total_supply");
const totalSupply: felt252 = selector!("totalSupply");
const allowance: felt252 = selector!("allowance");
const transfer: felt252 = selector!("transfer");

//
// Account
//

const set_public_key: felt252 = selector!("set_public_key");
const setPublicKey: felt252 = selector!("setPublicKey");
const get_public_key: felt252 = selector!("get_public_key");
const getPublicKey: felt252 = selector!("getPublicKey");
const is_valid_signature: felt252 = selector!("is_valid_signature");
const isValidSignature: felt252 = selector!("isValidSignature");
const supports_interface: felt252 = selector!("supports_interface");
const supportsInterface: felt252 = selector!("supportsInterface");
