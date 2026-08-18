use core::num::traits::Bounded;
use openzeppelin_account::MultisigAccountComponent::SIGNATURE_VERSION;
use openzeppelin_testing::signing::StarkKeyPair;
use snforge_std::signature::stark_curve::StarkCurveSignerImpl;

/// Builds the canonical multisig signature encoding for `hash`.
///
/// Signer records are sorted by ascending public key independently of the input order.
pub fn get_multisig_signature(hash: felt252, key_pairs: Span<StarkKeyPair>) -> Array<felt252> {
    let mut result = array![SIGNATURE_VERSION, key_pairs.len().into()];
    let mut previous_public_key: u256 = 0;
    let mut records_added = 0;

    while records_added < key_pairs.len() {
        let mut found = false;
        let mut selected_index = 0;
        let mut selected_public_key: u256 = Bounded::<u256>::MAX;

        for index in 0..key_pairs.len() {
            let key_pair = *key_pairs.at(index);
            let public_key: u256 = key_pair.public_key.into();
            if public_key > previous_public_key && (!found || public_key < selected_public_key) {
                found = true;
                selected_index = index;
                selected_public_key = public_key;
            }
        }

        assert(found, 'Duplicate signing key');
        let key_pair = *key_pairs.at(selected_index);
        let (r, s) = key_pair.sign(hash).unwrap();
        result.append(key_pair.public_key);
        result.append(r);
        result.append(s);
        previous_public_key = selected_public_key;
        records_added += 1;
    }

    result
}
