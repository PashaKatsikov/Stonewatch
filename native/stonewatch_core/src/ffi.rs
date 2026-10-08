//! Opaque C ABI consumed by `lib/core/stonewatch_core.dart`.
//!
//! The stateless game math (rules, economy, motion) is reached through a
//! single dispatcher keyed by an integer selector, so the dynamic symbol
//! table carries no function names that hint at what the code does. The
//! dice handle keeps a few short, meaningless exports because it hands
//! back a pointer and integers. Keep the selectors in sync with the Dart
//! side.

use core::ffi::c_void;

use crate::dice::Dice;
use crate::{economy, motion, rules};

fn bf(value: bool) -> f64 {
    if value { 1.0 } else { 0.0 }
}

/// Dispatches every stateless `f64 -> f64` routine. Unused arguments are
/// ignored; booleans come back as 1.0 / 0.0. Unknown selectors yield 0.0.
#[unsafe(no_mangle)]
pub extern "C" fn o9c(sel: u32, a: f64, b: f64, c: f64, d: f64, e: f64) -> f64 {
    match sel {
        1 => rules::foundation_width(),
        2 => rules::min_coefficient(),
        3 => rules::miss_ratio(),
        4 => rules::top_multiplier(),
        5 => rules::judge_landing(a, b, c, d, e),
        6 => rules::multiplier_for_ratio(a, b),
        7 => rules::grow_payout(a, b),

        8 => economy::min_bet(),
        9 => economy::starting_balance(),
        10 => economy::starting_bet(),
        11 => economy::money(a),
        12 => economy::opening_balance(a),
        13 => bf(economy::is_broke(a)),
        14 => economy::fit_bet(a, b),
        15 => economy::nudge_bet(a, b as i32, c),
        16 => economy::double_bet(a, b),
        17 => bf(economy::can_place(a, b)),
        18 => economy::debit(a, b),
        19 => economy::credit(a, b),

        20 => motion::frame_dt(a),
        21 => motion::swing_speed(a, b, c as u32),
        22 => motion::swing_reach(a as u32),
        23 => motion::swing_advance(a, b, c),
        24 => motion::swing_offset(a, b),
        25 => motion::hook_tilt(a),
        26 => motion::fall_step(a, b),
        27 => motion::tumble_step(a, b),
        28 => motion::collapse_step(a, b),
        29 => motion::camera_step(a, b),
        30 => motion::fall_ease(a),
        31 => motion::tumble_slide(a, b),
        32 => motion::tumble_drop(a),
        33 => motion::tumble_spin(a, b),
        34 => motion::collapse_sink(a),
        35 => motion::miss_direction(a, b),
        36 => motion::impact_shake(a != 0.0, b),
        37 => motion::shake_decay(a, b),
        38 => motion::shake_offset(a, b),
        39 => motion::shove_x(a, b),

        _ => 0.0,
    }
}

fn with_dice<T>(handle: *mut c_void, fallback: T, f: impl FnOnce(&mut Dice) -> T) -> T {
    if handle.is_null() {
        return fallback;
    }
    // SAFETY: non-null handles only ever come from `o1k` and are freed
    // exactly once by `o1x`.
    let dice = unsafe { &mut *(handle as *mut Dice) };
    f(dice)
}

#[unsafe(no_mangle)]
pub extern "C" fn o1k(seed: u64) -> *mut c_void {
    Box::into_raw(Box::new(Dice::new(seed))) as *mut c_void
}

/// # Safety
/// `handle` must be null or a pointer returned by `o1k` that has not been
/// freed yet.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn o1x(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }
    drop(unsafe { Box::from_raw(handle as *mut Dice) });
}

#[unsafe(no_mangle)]
pub extern "C" fn o2u(handle: *mut c_void) -> f64 {
    with_dice(handle, 0.0, Dice::unit)
}

#[unsafe(no_mangle)]
pub extern "C" fn o2b(handle: *mut c_void, n: u32) -> u32 {
    with_dice(handle, 0, |d| d.below(n))
}

#[unsafe(no_mangle)]
pub extern "C" fn o2r(handle: *mut c_void) -> u32 {
    with_dice(handle, crate::dice::ROUND_ID_FLOOR, Dice::round_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn o2o(handle: *mut c_void, art: u32, count: u32) -> u32 {
    with_dice(handle, art, |d| d.other_than(art, count))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dispatch_matches_modules() {
        assert_eq!(o9c(3, 0.0, 0.0, 0.0, 0.0, 0.0), rules::miss_ratio());
        assert_eq!(o9c(5, 0.0, 0.2, 0.0, 0.37, 0.0), 10.0);
        assert_eq!(o9c(13, 5.0, 0.0, 0.0, 0.0, 0.0), 1.0);
        assert_eq!(o9c(17, 10.0, 10.0, 0.0, 0.0, 0.0), 1.0);
        assert_eq!(o9c(999, 0.0, 0.0, 0.0, 0.0, 0.0), 0.0);
    }

    #[test]
    fn dice_handle_round_trip() {
        let handle = o1k(5);
        assert!(o2r(handle) >= crate::dice::ROUND_ID_FLOOR);
        assert!(o2b(handle, 5) < 5);
        assert_ne!(o2o(handle, 2, 5), 2);
        unsafe { o1x(handle) };
    }

    #[test]
    fn null_handle_is_harmless() {
        let null = core::ptr::null_mut();
        assert_eq!(o2u(null), 0.0);
        assert_eq!(o2o(null, 3, 5), 3);
        unsafe { o1x(null) };
    }
}
