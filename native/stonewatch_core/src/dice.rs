//! xoshiro256** seeded through splitmix64. Small, fast and good enough
//! for picking blocks, round ids and landing rolls.

pub const ROUND_ID_FLOOR: u32 = 100_000_000;
pub const ROUND_ID_SPAN: u32 = 900_000_000;

pub struct Dice {
    s: [u64; 4],
}

fn splitmix(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

impl Dice {
    pub fn new(seed: u64) -> Self {
        let mut state = seed;
        let mut s = [0u64; 4];
        for word in s.iter_mut() {
            *word = splitmix(&mut state);
        }
        if s == [0; 4] {
            s[0] = 1;
        }
        Self { s }
    }

    pub fn next_u64(&mut self) -> u64 {
        let result = self.s[1].wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        let t = self.s[1] << 17;
        self.s[2] ^= self.s[0];
        self.s[3] ^= self.s[1];
        self.s[1] ^= self.s[2];
        self.s[0] ^= self.s[3];
        self.s[2] ^= t;
        self.s[3] = self.s[3].rotate_left(45);
        result
    }

    /// Uniform in `[0, 1)`.
    pub fn unit(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 * (1.0 / (1u64 << 53) as f64)
    }

    /// Uniform in `[0, n)`; 0 when `n` is 0.
    pub fn below(&mut self, n: u32) -> u32 {
        if n == 0 {
            return 0;
        }
        (((self.next_u64() >> 32) * n as u64) >> 32) as u32
    }

    pub fn round_id(&mut self) -> u32 {
        ROUND_ID_FLOOR + self.below(ROUND_ID_SPAN)
    }

    /// A block index different from `art` whenever there is a choice.
    pub fn other_than(&mut self, art: u32, count: u32) -> u32 {
        if count < 2 {
            return art;
        }
        let mut next = self.below(count - 1);
        if next >= art {
            next += 1;
        }
        next
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_same_stream() {
        let mut a = Dice::new(42);
        let mut b = Dice::new(42);
        for _ in 0..32 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn ranges_hold() {
        let mut dice = Dice::new(7);
        for _ in 0..10_000 {
            let u = dice.unit();
            assert!((0.0..1.0).contains(&u));
            assert!(dice.below(5) < 5);
            let id = dice.round_id();
            assert!((ROUND_ID_FLOOR..ROUND_ID_FLOOR + ROUND_ID_SPAN).contains(&id));
        }
        assert_eq!(dice.below(0), 0);
    }

    #[test]
    fn other_than_never_repeats() {
        let mut dice = Dice::new(99);
        for art in 0..5 {
            for _ in 0..2_000 {
                let next = dice.other_than(art, 5);
                assert_ne!(next, art);
                assert!(next < 5);
            }
        }
        assert_eq!(dice.other_than(0, 1), 0);
    }

    #[test]
    fn every_block_shows_up() {
        let mut dice = Dice::new(3);
        let mut seen = [0u32; 5];
        for _ in 0..5_000 {
            seen[dice.below(5) as usize] += 1;
        }
        assert!(seen.iter().all(|&n| n > 800));
    }
}
