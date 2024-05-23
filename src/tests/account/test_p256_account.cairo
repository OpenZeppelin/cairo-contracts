use openzeppelin::account::interface::P256PublicKey;
use openzeppelin::account::utils::signature::P256Signature;
use starknet::secp256r1::secp256r1_new_syscall;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: u256,
    public_key: P256PublicKey,
    transaction_hash: felt252,
    signature: P256Signature
}

/// This signature was computed using @noble/curves.
fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 0x1efecf7ee1e25bb87098baf2aaab0406167aae0d5ea9ba0d31404bf01886bd0e,
        public_key: secp256r1_new_syscall(
            0x097420e05fbc83afe4d73b31890187d0cacf2c3653e27f434701a91625f916c2,
            0x98a304ff544db99c864308a9b3432324adc6c792181bae33fe7a4cbd48cf263a
        )
            .unwrap()
            .unwrap(),
        transaction_hash: 0x1e0cb9e0eb2a8b414df99964673bd493b594c4a627ab031c150ffc81b330706,
        signature: P256Signature {
            r: 0xfe4e53a283f4715bba1969dff40227c2ca24a6321a89a02e37a0b830c1a0918e,
            s: 0x52257a68cfe886341cfaf23841f744230f2af8dadf8bee2e6560c6bbfed8f28f,
        }
    }
}
