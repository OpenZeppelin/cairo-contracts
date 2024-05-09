use core::starknet::secp256_trait::Secp256PointTrait;
use openzeppelin::account::interface::P256PublicKey;
use openzeppelin::account::utils::secp256r1::{
    DebugSecp256r1Point, Secp256r1PointPartialEq, Secp256r1PointSerde
};
use openzeppelin::account::utils::signature::P256Signature;
use starknet::SyscallResultTrait;
use starknet::secp256r1::secp256r1_new_syscall;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: u256,
    public_key: P256PublicKey,
    transaction_hash: felt252,
    signature: P256Signature
}

/// This signature was computed using ethers.js.
fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 0x45397ee6ca34cb49060f1c303c6cb7ee2d6123e617601ef3e31ccf7bf5bef1f9,
        public_key: secp256r1_new_syscall(
            0x829307f82a1883c2414503ba85fc85037f22c6fc6f80910801f6b01a4131da1e,
            0x2a23f7bddf3715d11767b1247eccc68c89e11b926e2615268db6ad1af8d8da96
        )
            .unwrap()
            .unwrap(),
        transaction_hash: 0x008f882c63d0396d216d57529fe29ad5e70b6cd51b47bd2458b0a4ccb2ba0957,
        signature: EthSignature {
            r: 0x82bb3efc0554ec181405468f273b0dbf935cca47182b22da78967d0770f7dcc3,
            s: 0x6719fef30c11c74add873e4da0e1234deb69eae6a6bd4daa44b816dc199f3e86,
        }
    }
}
