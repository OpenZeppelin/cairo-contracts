//
// AccessControl
//

const get_role_admin: felt252 = 0x302e0454f48778e0ca3a2e714a289c4e8d8e03d614b370130abb1a524a47f22;
const getRoleAdmin: felt252 = 0x2034da88f3e3f3382ab0faf97fe5f74fe34d551ddff7fda974d756bf12130a0;
const grant_role: felt252 = 0x18a2f881894a5eb15a2a00f598839abaa75bd7f1fea1a37e42779d7fbcd9cf8;
const grantRole: felt252 = 0x37322ff1aabefe50aec25a14eb84b168b7be4f2d66fbbdb5dd8135e8234c37a;
const has_role: felt252 = 0x30559321b47d576b645ed7bd24089943dd5fd3a359ecdd6fa8f05c1bab67d6b;
const hasRole: felt252 = 0x35ed3407ba17dc741dd3af821fa1548619ebcdc87c95bcea9e3bc510951fae8;
const renounce_role: felt252 = 0xd80093a4ee6a9e649f2ae3c64963d5096948d50cf4ea055500aa03a342fd43;
const renounceRole: felt252 = 0x3c4022816cd5119ac7938fd7a982062e4cacd4777b4eda6e6a8f64d9e6833;
const revoke_role: felt252 = 0x246116ed358bad337e64a4df51cb57a40929189494ad5905a39872c489136ec;
const revokeRole: felt252 = 0xa7ef1739dec1e216a0ba2987650983a3104c707ad0831a30184a3b1382dd7d;

//
// Ownable
//

const owner: felt252 = 0x2016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0;
const transfer_ownership: felt252 =
    0x2a3bb1eaa05b77c4b0eeee0116a3177c6d62319dd7149ae148185d9e09de74a;
const transferOwnership: felt252 =
    0x14a390f291e2e1f29874769efdef47ddad94d76f77ff516fad206a385e8995f;
const renounce_ownership: felt252 = 0x52580a92c73f4428f1a260c5d768ef462b25955307de00f99957df119865d;
const renounceOwnership: felt252 = 0xd5d33d590e6660853069b37a2aea67c6fdaa0268626bc760350b590490feb5;

//
// ERC721
//

const name: felt252 = 0x361458367e696363fbcc70777d07ebbd2394e89fd0adcaf147faccd1d294d60;
const symbol: felt252 = 0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4;
const token_uri: felt252 = 0x226ad7e84c1fe08eb4c525ed93cccadf9517670341304571e66f7c4f95cbe54;
const tokenUri: felt252 = 0x362dec5b8b67ab667ad08e83a2c3ba1db7fdb4ab8dc3a33c057c4fddec8d3de;
const balance_of: felt252 = 0x35a73cd311a05d46deda634c5ee045db92f811b4e74bca4437fcb5302b7af33;
const balanceOf: felt252 = 0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e;
const owner_of: felt252 = 0x3552df12bdc6089cf963c40c4cf56fbfd4bd14680c244d1c5494c2790f1ea5c;
const ownerOf: felt252 = 0x2962ba17806af798afa6eaf4aa8c93a9fb60a3e305045b6eea33435086cae9;
const get_approved: felt252 = 0x309065f1424d76d4a4ace2ff671391d59536e0297409434908d38673290a749;
const getApproved: felt252 = 0xb180e2fe9f14914416216da76338ac0beb980443725c802af615f8431fdb1e;
const is_approved_for_all: felt252 =
    0x2aa3ea196f9b8a4f65613b67fcf185e69d8faa9601a3382871d15b3060e30dd;
const isApprovedForAll: felt252 = 0x21cdf9aedfed41bc4485ae779fda471feca12075d9127a0fc70ac6b3b3d9c30;
const approve: felt252 = 0x219209e083275171774dab1df80982e9df2096516f06319c5c6d71ae0a8480c;
const set_approval_for_all: felt252 =
    0xd86ca3d41635e20c180181046b11abcf19e1bdef3dcaa4c180300ccca1813f;
const setApprovalForAll: felt252 =
    0x2d4c8ea4c8fb9f571d1f6f9b7692fff8e5ceaf73b1df98e7da8c1109b39ae9a;
const transfer_from: felt252 = 0x3704ffe8fba161be0e994951751a5033b1462b918ff785c0a636be718dfdb68;
const transferFrom: felt252 = 0x41b033f4a31df8067c24d1e9b550a2ce75fd4a29e1147af9752174f0e6cb20;
const safe_transfer_from: felt252 =
    0x16f0218b33b5cf273196787d7cf139a9ad13d58e6674dcdce722b3bf8389863;
const safeTransferFrom: felt252 = 0x19d59d013d4aa1a8b1ce4c8299086f070733b453c02d0dc46e735edc04d6444;

//
// ERC721Receiver
//

const on_erc721_received: felt252 =
    0x38c7ee9f0855dfe219aea022b141d9b2ec0f6b68395d221c3f331c7ca4fb608;
const onERC721Received: felt252 = 0xfa119a8fafc6f1a02deb36fe5efbcc4929ef2021e50cf1cb6d1a780ccd009b;

//
// ERC20
//

// The following ERC20 selectors are already defined in ERC721 above:
// name, symbol, balance_of, balanceOf, transfer_from, transferFrom, approve
const decimals: felt252 = 0x4c4fb1ab068f6039d5780c68dd0fa2f8742cceb3426d19667778ca7f3518a9;
const total_supply: felt252 = 0x1557182e4359a1f0c6301278e8f5b35a776ab58d39892581e357578fb287836;
const totalSupply: felt252 = 0x80aa9fdbfaf9615e4afc7f5f722e265daca5ccc655360fa5ccacf9c267936d;
const allowance: felt252 = 0x1e888a1026b19c8c0b57c72d63ed1737106aa10034105b980ba117bd0c29fe1;
const transfer: felt252 = 0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e;

//
// Account
//

const set_public_key: felt252 = 0x2e3e21ff5952b2531241e37999d9c4c8b3034cccc89a202a6bf019bdf5294f9;
const setPublicKey: felt252 = 0xbc0eb87884ab91e330445c3584a50d7ddf4b568f02fbeb456a6242cce3f5d9;
const get_public_key: felt252 = 0x1a35984e05126dbecb7c3bb9929e7dd9106d460c59b1633739a5c733a5fb13b;
const getPublicKey: felt252 = 0x1a6c6a0bdec86cc645c91997d8eea83e87148659e3e61122f72361fd5e94079;
const is_valid_signature: felt252 =
    0x28420862938116cb3bbdbedee07451ccc54d4e9412dbef71142ad1980a30941;
const isValidSignature: felt252 = 0x213dfe25e2ca309c4d615a09cfc95fdb2fc7dc73fbcad12c450fe93b1f2ff9e;
const supports_interface: felt252 =
    0xfe80f537b66d12a00b6d3c072b44afbb716e78dde5c3f0ef116ee93d3e3283;
const supportsInterface: felt252 =
    0x29e211664c0b63c79638fbea474206ca74016b3e9a3dc4f9ac300ffd8bdf2cd;
