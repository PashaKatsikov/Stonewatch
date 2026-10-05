//! Swing, fall, tumble and shake kinematics. Horizontal positions are
//! in stage widths from the centre, vertical drops in stage heights.

crate::veiled_f! {
    base_swing_speed => 2.15,
    swing_speed_per_floor => 0.28,
    swing_speed_per_heat => 0.12,
    max_heat => 6.0,
    base_reach => 0.26,
    reach_per_floor => 0.018,
    max_reach => 0.36,
    hook_tilt_amp => 0.045,

    fall_seconds => 0.38,
    tumble_seconds => 0.46,
    collapse_seconds => 0.7,
    camera_seconds => 0.32,

    tumble_slide_span => 0.62,
    tumble_drop_span => 0.48,
    tumble_spin_span => 1.5,
    collapse_sink_span => 0.55,

    shake_decay_rate => 7.0,
    shake_floor => 0.15,
    shake_frequency => 52.0,
    shake_soft_hit => 5.0,
    shake_hard_hit => 9.0,
    shake_miss => 14.0,
    hard_hit_multiplier => 2.0,

    frame_fallback => 1.0 / 60.0,
    frame_cap => 0.05,

    shove_distance => 0.72,
    shove_limit => 0.9,
}

fn unit(t: f64) -> f64 {
    t.clamp(0.0, 1.0)
}

/// Frame delta in seconds; stalls and clock jumps fall back to 60 fps.
pub fn frame_dt(raw: f64) -> f64 {
    if raw <= 0.0 || raw > frame_cap() || raw.is_nan() {
        frame_fallback()
    } else {
        raw
    }
}

pub fn swing_speed(stake: f64, payout: f64, floors: u32) -> f64 {
    let heat = if stake <= 0.0 {
        0.0
    } else {
        (payout / stake - 1.0).clamp(0.0, max_heat())
    };
    base_swing_speed() + floors as f64 * swing_speed_per_floor() + heat * swing_speed_per_heat()
}

pub fn swing_reach(floors: u32) -> f64 {
    max_reach().min(base_reach() + floors as f64 * reach_per_floor())
}

pub fn swing_advance(phase: f64, dt: f64, speed: f64) -> f64 {
    phase + dt * speed
}

pub fn swing_offset(phase: f64, reach: f64) -> f64 {
    phase.sin() * reach
}

pub fn hook_tilt(phase: f64) -> f64 {
    phase.cos() * hook_tilt_amp()
}

pub fn fall_step(t: f64, dt: f64) -> f64 {
    t + dt / fall_seconds()
}

pub fn tumble_step(t: f64, dt: f64) -> f64 {
    t + dt / tumble_seconds()
}

pub fn collapse_step(t: f64, dt: f64) -> f64 {
    t + dt / collapse_seconds()
}

pub fn camera_step(t: f64, dt: f64) -> f64 {
    if t < 1.0 {
        1.0f64.min(t + dt / camera_seconds())
    } else {
        t
    }
}

/// Gravity-style ease of the falling block, 0 at release, 1 on impact.
pub fn fall_ease(t: f64) -> f64 {
    let u = unit(t);
    u * u
}

pub fn tumble_slide(direction: f64, t: f64) -> f64 {
    let u = unit(t);
    direction * u * u * tumble_slide_span()
}

pub fn tumble_drop(t: f64) -> f64 {
    let u = unit(t);
    u * u * tumble_drop_span()
}

pub fn tumble_spin(direction: f64, t: f64) -> f64 {
    direction * unit(t) * tumble_spin_span()
}

pub fn collapse_sink(amount: f64) -> f64 {
    amount * amount * collapse_sink_span()
}

pub fn miss_direction(block_x: f64, top_x: f64) -> f64 {
    if block_x - top_x >= 0.0 { 1.0 } else { -1.0 }
}

pub fn impact_shake(held: bool, multiplier: f64) -> f64 {
    if !held {
        shake_miss()
    } else if multiplier >= hard_hit_multiplier() {
        shake_hard_hit()
    } else {
        shake_soft_hit()
    }
}

pub fn shake_decay(shake: f64, dt: f64) -> f64 {
    if shake > shake_floor() {
        shake * (-shake_decay_rate() * dt).exp()
    } else {
        0.0
    }
}

pub fn shake_offset(clock: f64, shake: f64) -> f64 {
    if shake == 0.0 {
        0.0
    } else {
        (clock * shake_frequency()).sin() * shake
    }
}

/// Where a forced miss throws the block: well past the tower edge on the
/// side it was swinging, kept on screen.
pub fn shove_x(swung: f64, top_x: f64) -> f64 {
    let side = if swung >= top_x { 1.0 } else { -1.0 };
    (top_x + side * shove_distance()).clamp(-shove_limit(), shove_limit())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn swing_gets_faster_and_wider_with_height() {
        assert_eq!(swing_speed(0.0, 0.0, 0), 2.15);
        assert!((swing_speed(100.0, 300.0, 2) - (2.15 + 0.56 + 0.24)).abs() < 1e-12);
        assert!((swing_speed(100.0, 10_000.0, 0) - (2.15 + 0.72)).abs() < 1e-12);
        assert_eq!(swing_reach(0), 0.26);
        assert_eq!(swing_reach(20), 0.36);
    }

    #[test]
    fn frames_are_sanitised() {
        assert_eq!(frame_dt(0.016), 0.016);
        assert_eq!(frame_dt(0.0), 1.0 / 60.0);
        assert_eq!(frame_dt(0.2), 1.0 / 60.0);
    }

    #[test]
    fn camera_settles_at_one() {
        assert_eq!(camera_step(0.9, 1.0), 1.0);
        assert_eq!(camera_step(1.0, 1.0), 1.0);
        assert!((camera_step(0.0, 0.16) - 0.5).abs() < 1e-12);
    }

    #[test]
    fn shake_dies_out() {
        assert_eq!(shake_decay(0.1, 0.016), 0.0);
        assert!(shake_decay(9.0, 0.016) < 9.0);
        assert_eq!(shake_offset(3.0, 0.0), 0.0);
        assert_eq!(impact_shake(true, 1.5), 5.0);
        assert_eq!(impact_shake(true, 2.0), 9.0);
        assert_eq!(impact_shake(false, 0.0), 14.0);
    }

    #[test]
    fn tumble_and_shove() {
        assert_eq!(fall_ease(2.0), 1.0);
        assert_eq!(tumble_slide(-1.0, 1.0), -0.62);
        assert_eq!(tumble_drop(1.0), 0.48);
        assert_eq!(tumble_spin(1.0, 0.5), 0.75);
        assert_eq!(collapse_sink(1.0), 0.55);
        assert_eq!(miss_direction(0.0, 0.0), 1.0);
        assert_eq!(shove_x(0.1, 0.0), 0.72);
        assert_eq!(shove_x(-0.6, -0.5), -0.9);
        assert!((shove_x(-0.1, -0.5) - 0.22).abs() < 1e-12);
    }
}
