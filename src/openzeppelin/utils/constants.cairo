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

//
// Selectors
//

const has_role_SELECTOR: felt252 =
    0x30559321b47d576b645ed7bd24089943dd5fd3a359ecdd6fa8f05c1bab67d6b;
const hasRole_SELECTOR: felt252 = 0x35ed3407ba17dc741dd3af821fa1548619ebcdc87c95bcea9e3bc510951fae8;
const get_role_admin_SELECTOR: felt252 =
    0x302e0454f48778e0ca3a2e714a289c4e8d8e03d614b370130abb1a524a47f22;
const getRoleAdmin_SELECTOR: felt252 =
    0x2034da88f3e3f3382ab0faf97fe5f74fe34d551ddff7fda974d756bf12130a0;
const grant_role_SELECTOR: felt252 =
    0x18a2f881894a5eb15a2a00f598839abaa75bd7f1fea1a37e42779d7fbcd9cf8;
const grantRole_SELECTOR: felt252 =
    0x37322ff1aabefe50aec25a14eb84b168b7be4f2d66fbbdb5dd8135e8234c37a;
const revoke_role_SELECTOR: felt252 =
    0x246116ed358bad337e64a4df51cb57a40929189494ad5905a39872c489136ec;
const revokeRole_SELECTOR: felt252 =
    0xa7ef1739dec1e216a0ba2987650983a3104c707ad0831a30184a3b1382dd7d;
const renounce_role_SELECTOR: felt252 =
    0xd80093a4ee6a9e649f2ae3c64963d5096948d50cf4ea055500aa03a342fd43;
const renounceRole_SELECTOR: felt252 =
    0x3c4022816cd5119ac7938fd7a982062e4cacd4777b4eda6e6a8f64d9e6833;
