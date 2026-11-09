pub mod bounded_int {
    #[feature("bounded-int-utils")]
    pub use core::internal::bounded_int;
    #[feature("bounded-int-utils")]
    pub use core::internal::bounded_int::{
        AddHelper, BoundedInt, ConstrainHelper, DivRemHelper, MulHelper, SubHelper, UnitInt,
        bounded_int_add, bounded_int_div_rem, constrain, downcast, upcast,
    };
}
