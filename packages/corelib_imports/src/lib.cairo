pub mod bounded_int {
    #[feature("bounded-int-utils")]
    pub use core::internal::bounded_int::{
        AddHelper, BoundedInt, DivRemHelper, UnitInt, bounded_int_add, bounded_int_div_rem,
        downcast, upcast,
    };
}
