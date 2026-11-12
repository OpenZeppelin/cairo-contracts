mod extensions;

mod falcon_512_account_mocks;
mod test_account;
mod test_eth_account;
mod test_falcon_512;
mod test_falcon_512_ntt;

#[cfg(feature: 'falcon_fast_tests')]
mod test_falcon_512_packed_ntt;
mod test_multisig_account;
mod test_secp256_point;
mod test_signature;
