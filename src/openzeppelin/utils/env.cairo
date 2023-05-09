use option::OptionTrait;

#[inline(always)]
fn check_gas() {
    gas::withdraw_gas().expect('Out of gas');
}