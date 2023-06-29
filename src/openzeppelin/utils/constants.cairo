//
// Interface ids
//

// ERC165
// See: https://eips.ethereum.org/EIPS/eip-165
const IERC165_ID: u32 = 0x01ffc9a7_u32;
const INVALID_ID: u32 = 0xffffffff_u32;

// Account
// See: https://github.com/OpenZeppelin/cairo-contracts/pull/449#discussion_r966242914
const IACCOUNT_ID: u32 = 0xa66bd575_u32;

// ERC721
// See: https://eips.ethereum.org/EIPS/eip-721
const IERC721_ID: u32 = 0x80ac58cd_u32;
const IERC721_RECEIVER_ID: u32 = 0x150b7a02_u32;
const IERC721_METADATA_ID: u32 = 0x5b5e139f_u32;
const IERC721_ENUMERABLE_ID: u32 = 0x780e9d63_u32;

// ERC1155
// See: https://eips.ethereum.org/EIPS/eip-1155
const IERC1155_ID: u32 = 0xd9b67a26_u32;
const IERC1155_METADATA_ID: u32 = 0x0e89341c_u32;
const IERC1155_RECEIVER_ID: u32 = 0x4e2312e0_u32;
const ON_ERC1155_RECEIVED_SELECTOR: u32 = 0xf23a6e61_u32;
const ON_ERC1155_BATCH_RECEIVED_SELECTOR: u32 = 0xbc197c81_u32;

// AccessControl
// Calculated from XOR of all function selectors in IAccessControl.
// See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/IAccessControl.sol
const IACCESSCONTROL_ID: u32 = 0x7965db0b_u32;

//
// Roles
//

const DEFAULT_ADMIN_ROLE: felt252 = 0;
