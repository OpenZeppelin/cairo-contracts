pub mod bounded_int {
    #[feature("bounded-int-utils")]
    pub use core::internal::bounded_int::{
        BoundedInt, DivRemHelper, UnitInt, bounded_int_div_rem, downcast, upcast,
    };
}

pub mod integer {
    pub use core::integer::{U128sFromFelt252Result, u128s_from_felt252};
}
