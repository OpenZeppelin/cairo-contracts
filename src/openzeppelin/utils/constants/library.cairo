// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (utils/constants/library.cairo)

%lang starknet

//
// Numbers
//

const UINT8_MAX = 255;

//
// Interface Ids
//

// ERC165
const IERC165_ID = 0x01ffc9a7;
const INVALID_ID = 0xffffffff;

// Account
const IACCOUNT_ID = 0xa66bd575;

// ERC721
const IERC721_ID = 0x80ac58cd;
const IERC721_RECEIVER_ID = 0x150b7a02;
const IERC721_METADATA_ID = 0x5b5e139f;
const IERC721_ENUMERABLE_ID = 0x780e9d63;

// ERC1155
const IERC1155_ID = 0xd9b67a26;
const IERC1155_METADATA_ID = 0x0e89341c;
const IERC1155_RECEIVER_ID = 0x4e2312e0;
const ON_ERC1155_RECEIVED_SELECTOR = 0xf23a6e61;
const ON_ERC1155_BATCH_RECEIVED_SELECTOR = 0xbc197c81;

// AccessControl
const IACCESSCONTROL_ID = 0x7965db0b;

//
// Roles
//

const DEFAULT_ADMIN_ROLE = 0;

//
// Starknet
//

const TRANSACTION_VERSION = 1;
