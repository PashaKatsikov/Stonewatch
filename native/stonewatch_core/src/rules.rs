use crate::veil::{self, ef};

crate::veiled_f! {
    foundation_width => 0.37,
    min_coefficient => 0.4,
    miss_ratio => 0.38,
    roll_cap => 0.999,
}

/// Upper overlap-ratio bound of each band and the three multipliers a
/// roll picks from inside it, all stored masked. The last bound is above
/// 1 so a perfect stack always lands in the jackpot band.
const BANDS: [(u64, [u64; 3]); 6] = [
    (ef(0.50), [ef(0.4), ef(0.45), ef(0.5)]),
    (ef(0.63), [ef(0.8), ef(1.0), ef(1.1)]),
    (ef(0.75), [ef(1.25), ef(1.5), ef(1.85)]),
    (ef(0.86), [ef(2.0), ef(2.5), ef(2.9)]),
    (ef(0.94), [ef(3.5), ef(5.0), ef(8.0)]),
    (ef(2.0), [ef(10.0), ef(15.0), ef(25.0)]),
];

fn band(i: usize) -> (f64, [f64; 3]) {
    let (bound, picks) = BANDS[i];
    (
        veil::df(bound),
        [veil::df(picks[0]), veil::df(picks[1]), veil::df(picks[2])],
    )
}

pub fn top_multiplier() -> f64 {
    band(BANDS.len() - 1).1[2]
}

pub fn overlap(ax: f64, aw: f64, bx: f64, bw: f64) -> f64 {
    let left = ax - aw / 2.0;
    let right = ax + aw / 2.0;
    let top_left = bx - bw / 2.0;
    let top_right = bx + bw / 2.0;
    let hit = right.min(top_right) - left.max(top_left);
    if hit > 0.0 { hit } else { 0.0 }
}

pub fn overlap_ratio(block_x: f64, block_w: f64, top_x: f64, top_w: f64) -> f64 {
    if block_w <= 0.0 {
        return 0.0;
    }
    overlap(block_x, block_w, top_x, top_w) / block_w
}

/// Multiplier earned by a landing, or 0 when the block slides off.
pub fn judge_landing(block_x: f64, block_w: f64, top_x: f64, top_w: f64, roll: f64) -> f64 {
    let ratio = overlap_ratio(block_x, block_w, top_x, top_w);
    if ratio < miss_ratio() {
        return 0.0;
    }
    multiplier_for_ratio(ratio, roll)
}

pub fn multiplier_for_ratio(ratio: f64, roll: f64) -> f64 {
    let t = if roll.is_nan() { 0.0 } else { roll.clamp(0.0, roll_cap()) };
    for i in 0..BANDS.len() {
        let (bound, picks) = band(i);
        if ratio < bound {
            let slot = ((t * picks.len() as f64).floor() as usize).min(picks.len() - 1);
            return picks[slot];
        }
    }
    top_multiplier()
}

pub fn grow_payout(payout: f64, multiplier: f64) -> f64 {
    (payout * multiplier * 100.0).round() / 100.0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn centred_block_hits_jackpot_band() {
        assert_eq!(judge_landing(0.0, 0.2, 0.0, 0.37, 0.0), 10.0);
        assert_eq!(judge_landing(0.0, 0.2, 0.0, 0.37, 0.999), 25.0);
    }

    #[test]
    fn thin_overlap_is_a_miss() {
        assert_eq!(judge_landing(0.3, 0.2, 0.0, 0.2, 0.5), 0.0);
        assert_eq!(judge_landing(0.0, 0.0, 0.0, 0.2, 0.5), 0.0);
    }

    #[test]
    fn bands_follow_overlap_ratio() {
        assert_eq!(multiplier_for_ratio(0.40, 0.0), 0.4);
        assert_eq!(multiplier_for_ratio(0.55, 0.5), 1.0);
        assert_eq!(multiplier_for_ratio(0.70, 0.9), 1.85);
        assert_eq!(multiplier_for_ratio(0.80, 0.4), 2.5);
        assert_eq!(multiplier_for_ratio(0.90, 0.7), 8.0);
        assert_eq!(multiplier_for_ratio(1.0, 1.5), 25.0);
    }

    #[test]
    fn constants_decode_cleanly() {
        assert_eq!(foundation_width(), 0.37);
        assert_eq!(min_coefficient(), 0.4);
        assert_eq!(miss_ratio(), 0.38);
        assert_eq!(top_multiplier(), 25.0);
    }

    #[test]
    fn payout_rounds_to_cents() {
        assert_eq!(grow_payout(100.0, 1.85), 185.0);
        assert_eq!(grow_payout(33.33, 0.45), 15.0);
        assert_eq!(grow_payout(10.0, 0.0), 0.0);
    }
}
