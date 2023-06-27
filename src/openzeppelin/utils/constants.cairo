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

const name_SELECTOR: felt252 = 0x361458367e696363fbcc70777d07ebbd2394e89fd0adcaf147faccd1d294d60;
const symbol_SELECTOR: felt252 = 0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4;
const decimals_SELECTOR: felt252 = 0x4c4fb1ab068f6039d5780c68dd0fa2f8742cceb3426d19667778ca7f3518a9;
const total_supply_SELECTOR: felt252 =
    0x1557182e4359a1f0c6301278e8f5b35a776ab58d39892581e357578fb287836;
const totalSupply_SELECTOR: felt252 =
    0x80aa9fdbfaf9615e4afc7f5f722e265daca5ccc655360fa5ccacf9c267936d;
const balance_of_SELECTOR: felt252 =
    0x35a73cd311a05d46deda634c5ee045db92f811b4e74bca4437fcb5302b7af33;
const balanceOf_SELECTOR: felt252 =
    0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e;
const allowance_SELECTOR: felt252 =
    0x1e888a1026b19c8c0b57c72d63ed1737106aa10034105b980ba117bd0c29fe1;
const transfer_SELECTOR: felt252 = 0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e;
const transfer_from_SELECTOR: felt252 =
    0x3704ffe8fba161be0e994951751a5033b1462b918ff785c0a636be718dfdb68;
const transferFrom_SELECTOR: felt252 =
    0x41b033f4a31df8067c24d1e9b550a2ce75fd4a29e1147af9752174f0e6cb20;
const approve_SELECTOR: felt252 = 0x219209e083275171774dab1df80982e9df2096516f06319c5c6d71ae0a8480c;

