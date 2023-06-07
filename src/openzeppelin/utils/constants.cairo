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

const NAME_SELECTOR: felt252 = 0x361458367e696363fbcc70777d07ebbd2394e89fd0adcaf147faccd1d294d60;
const SYMBOL_SELECTOR: felt252 = 0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4;
const TOKEN_URI_SELECTOR: felt252 =
    0x226ad7e84c1fe08eb4c525ed93cccadf9517670341304571e66f7c4f95cbe54;
const TOKENURI_SELECTOR: felt252 =
    0x362dec5b8b67ab667ad08e83a2c3ba1db7fdb4ab8dc3a33c057c4fddec8d3de;
const BALANCE_OF_SELECTOR: felt252 =
    0x35a73cd311a05d46deda634c5ee045db92f811b4e74bca4437fcb5302b7af33;
const BALANCEOF_SELECTOR: felt252 =
    0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e;
const OWNER_OF_SELECTOR: felt252 =
    0x3552df12bdc6089cf963c40c4cf56fbfd4bd14680c244d1c5494c2790f1ea5c;
const OWNEROF_SELECTOR: felt252 = 0x2962ba17806af798afa6eaf4aa8c93a9fb60a3e305045b6eea33435086cae9;
const GET_APPROVED_SELECTOR: felt252 =
    0x309065f1424d76d4a4ace2ff671391d59536e0297409434908d38673290a749;
const GETAPPROVED_SELECTOR: felt252 =
    0xb180e2fe9f14914416216da76338ac0beb980443725c802af615f8431fdb1e;
const IS_APPROVED_FOR_ALL_SELECTOR: felt252 =
    0x2aa3ea196f9b8a4f65613b67fcf185e69d8faa9601a3382871d15b3060e30dd;
const ISAPPROVEDFORALL_SELECTOR: felt252 =
    0x21cdf9aedfed41bc4485ae779fda471feca12075d9127a0fc70ac6b3b3d9c30;
const APPROVE_SELECTOR: felt252 = 0x219209e083275171774dab1df80982e9df2096516f06319c5c6d71ae0a8480c;
const SET_APPROVAL_FOR_ALL_SELECTOR: felt252 =
    0xd86ca3d41635e20c180181046b11abcf19e1bdef3dcaa4c180300ccca1813f;
const SETAPPROVALFORALL_SELECTOR: felt252 =
    0x2d4c8ea4c8fb9f571d1f6f9b7692fff8e5ceaf73b1df98e7da8c1109b39ae9a;
const TRANSFER_FROM_SELECTOR: felt252 =
    0x3704ffe8fba161be0e994951751a5033b1462b918ff785c0a636be718dfdb68;
const TRANSFERFROM_SELECTOR: felt252 =
    0x41b033f4a31df8067c24d1e9b550a2ce75fd4a29e1147af9752174f0e6cb20;
const SAFE_TRANSFER_FROM_SELECTOR: felt252 =
    0x16f0218b33b5cf273196787d7cf139a9ad13d58e6674dcdce722b3bf8389863;
const SAFETRANSFERFROM_SELECTOR: felt252 =
    0x19d59d013d4aa1a8b1ce4c8299086f070733b453c02d0dc46e735edc04d6444;
