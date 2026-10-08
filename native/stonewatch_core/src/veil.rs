//! Constant veiling. Every distinctive game number is stored as a masked
//! bit pattern and only unmasked at runtime, so a scan of the shipped
//! `.rodata` never turns up a readable `0.38`, band table or timing.

use core::hint::black_box;

/// Keystream applied to every stored bit pattern. Meaningless alone.
const MASK: u64 = 0x5A13_E790_4CB2_6F38;

/// Compile-time encode: only the masked pattern reaches the binary.
pub const fn ef(value: f64) -> u64 {
    value.to_bits() ^ MASK
}

/// Runtime decode. The `black_box` is an optimiser barrier so the
/// unmasked value is never constant-folded back into a literal; it only
/// ever exists in a register while a call is running.
#[inline(never)]
pub fn df(enc: u64) -> f64 {
    f64::from_bits(black_box(enc) ^ MASK)
}

/// Declares a set of veiled `f64` accessors. Each generated function
/// carries only the encoded constant and decodes on call.
#[macro_export]
macro_rules! veiled_f {
    ($($name:ident => $value:expr),* $(,)?) => {
        $(
            #[inline]
            pub fn $name() -> f64 {
                const E: u64 = $crate::veil::ef($value);
                $crate::veil::df(E)
            }
        )*
    };
}
