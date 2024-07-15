use core::num::traits::Zero;

const max_denominator: u256 = 10000;

#[derive(Serde, Drop, PartialEq, Copy, Debug, starknet::Store)]
pub struct FeesRatio {
    pub numerator: u256,
    pub denominator: u256,
}

pub trait IFees<T> {
    fn compute_amount(self: @T, sale_price: u256) -> u256;
    fn is_valid(self: @T) -> bool;
}


pub impl FeesRatioDefault of Default<FeesRatio> {
    fn default() -> FeesRatio {
        FeesRatio { numerator: 0, denominator: 1, }
    }
}

pub impl FeesImpl of IFees<FeesRatio> {
    fn compute_amount(self: @FeesRatio, sale_price: u256) -> u256 {
        (sale_price * *self.numerator) / *self.denominator
    }

    fn is_valid(self: @FeesRatio) -> bool {
        (*self.numerator < *self.denominator)
            && (*self).denominator.is_non_zero()
            && (*self.denominator <= max_denominator)
    }
}
