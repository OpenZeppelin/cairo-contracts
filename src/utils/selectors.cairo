// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (utils/selectors.cairo)

//
// AccessControl
//

pub const get_role_admin: felt252 = selector!("get_role_admin");
pub const getRoleAdmin: felt252 = selector!("getRoleAdmin");
pub const grant_role: felt252 = selector!("grant_role");
pub const grantRole: felt252 = selector!("grantRole");
pub const has_role: felt252 = selector!("has_role");
pub const hasRole: felt252 = selector!("hasRole");
pub const renounce_role: felt252 = selector!("renounce_role");
pub const renounceRole: felt252 = selector!("renounceRole");
pub const revoke_role: felt252 = selector!("revoke_role");
pub const revokeRole: felt252 = selector!("revokeRole");

//
// Ownable
//

pub const owner: felt252 = selector!("owner");
pub const transfer_ownership: felt252 = selector!("transfer_ownership");
pub const transferOwnership: felt252 = selector!("transferOwnership");
pub const renounce_ownership: felt252 = selector!("renounce_ownership");
pub const renounceOwnership: felt252 = selector!("renounceOwnership");

//
// ERC721
//

pub const name: felt252 = selector!("name");
pub const symbol: felt252 = selector!("symbol");
pub const token_uri: felt252 = selector!("token_uri");
pub const tokenURI: felt252 = selector!("tokenURI");
pub const balance_of: felt252 = selector!("balance_of");
pub const balanceOf: felt252 = selector!("balanceOf");
pub const owner_of: felt252 = selector!("owner_of");
pub const ownerOf: felt252 = selector!("ownerOf");
pub const get_approved: felt252 = selector!("get_approved");
pub const getApproved: felt252 = selector!("getApproved");
pub const is_approved_for_all: felt252 = selector!("is_approved_for_all");
pub const isApprovedForAll: felt252 = selector!("isApprovedForAll");
pub const approve: felt252 = selector!("approve");
pub const set_approval_for_all: felt252 = selector!("set_approval_for_all");
pub const setApprovalForAll: felt252 = selector!("setApprovalForAll");
pub const transfer_from: felt252 = selector!("transfer_from");
pub const transferFrom: felt252 = selector!("transferFrom");
pub const safe_transfer_from: felt252 = selector!("safe_transfer_from");
pub const safeTransferFrom: felt252 = selector!("safeTransferFrom");

//
// ERC721Receiver
//

pub const on_erc721_received: felt252 = selector!("on_erc721_received");
pub const onERC721Received: felt252 = selector!("onERC721Received");

//
// ERC1155
//

// The following ERC1155 selectors are already defined in ERC721 above:
// balance_of, balanceOf, set_approval_for_all,
// setApprovalForAll, safe_transfer_from, safeTransferFrom
pub const uri: felt252 = selector!("uri");
pub const balance_of_batch: felt252 = selector!("balance_of_batch");
pub const balanceOfBatch: felt252 = selector!("balanceOfBatch");
pub const safe_batch_transfer_from: felt252 = selector!("safe_batch_transfer_from");
pub const safeBatchTransferFrom: felt252 = selector!("safeBatchTransferFrom");

//
// ERC1155Receiver
//

pub const on_erc1155_received: felt252 = selector!("on_erc1155_received");
pub const onERC1155Received: felt252 = selector!("onERC1155Received");
pub const on_erc1155_batch_received: felt252 = selector!("on_erc1155_batch_received");
pub const onERC1155BatchReceived: felt252 = selector!("onERC1155BatchReceived");

//
// ERC20
//

// The following ERC20 selectors are already defined in ERC721 above:
// name, symbol, balance_of, balanceOf, transfer_from, transferFrom, approve
pub const decimals: felt252 = selector!("decimals");
pub const total_supply: felt252 = selector!("total_supply");
pub const totalSupply: felt252 = selector!("totalSupply");
pub const allowance: felt252 = selector!("allowance");
pub const transfer: felt252 = selector!("transfer");

//
// Account
//

pub const set_public_key: felt252 = selector!("set_public_key");
pub const setPublicKey: felt252 = selector!("setPublicKey");
pub const get_public_key: felt252 = selector!("get_public_key");
pub const getPublicKey: felt252 = selector!("getPublicKey");
pub const is_valid_signature: felt252 = selector!("is_valid_signature");
pub const isValidSignature: felt252 = selector!("isValidSignature");
pub const supports_interface: felt252 = selector!("supports_interface");
