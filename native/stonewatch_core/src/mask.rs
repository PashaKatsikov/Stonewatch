//! Runtime string de-obfuscator for the gray-part secret vault.
//!
//! Mirror of the offline sealer in `tool/transcode_vault.dart`: a symmetric
//! keystream XOR, so masking and unmasking are the same operation. Every
//! gray-part string (endpoint, attribution key, Firebase number, the
//! browser-identity fragments, the WebView JS bodies and the gray-surface
//! copy) ships only as a masked array in `vault.rs` and is turned back into
//! bytes here, at call time — never as a readable literal in `.rodata`.
//!
//! The keystream shape (FNV-1a fold -> Numerical-Recipes LCG -> Fibonacci
//! drift) and its grain/span are unique to this build and deliberately
//! distinct from any sibling decoder.

// Project-unique grain. Distinct from every sibling build.
const GRAIN: [u8; 18] = [
    0xC4, 0x9A, 0x27, 0x5E, 0xB1, 0x08, 0xF3, 0x6D, 0x42,
    0x97, 0x1C, 0xA5, 0x7B, 0xE0, 0x39, 0x84, 0xD6, 0x2F,
];

// Keystream length. Project-unique.
const SPAN: usize = 31;

const FNV_OFFSET: u32 = 0x811C_9DC5;
const FNV_PRIME: u32 = 0x0100_0193;
const LCG_MUL: u32 = 0x0019_660D; // 1664525
const LCG_ADD: u32 = 0x3C6E_F35F; // 1013904223
const DRIFT_MUL: u32 = 0x85EB_CA77; // murmur finalizer constant

fn accumulate() -> u32 {
    let mut acc = FNV_OFFSET;
    for &b in GRAIN.iter() {
        acc = (acc ^ b as u32).wrapping_mul(FNV_PRIME);
    }
    if acc == 0 {
        FNV_PRIME
    } else {
        acc
    }
}

fn keystream() -> [u8; SPAN] {
    let mut state = accumulate();
    let mut ks = [0u8; SPAN];
    for slot in ks.iter_mut() {
        state = LCG_MUL.wrapping_mul(state).wrapping_add(LCG_ADD);
        *slot = (state >> 24) as u8;
    }
    ks
}

#[inline]
fn drift(index: usize) -> u8 {
    ((index as u32).wrapping_mul(DRIFT_MUL) >> 19) as u8
}

/// Reveal the plaintext bytes behind a masked array. Empty in -> empty out,
/// which is the expected state for an unsealed slot (e.g. a JS body).
pub fn unmask(cipher: &[u8]) -> Vec<u8> {
    let ks = keystream();
    cipher
        .iter()
        .enumerate()
        .map(|(i, &b)| b ^ ks[i % SPAN] ^ drift(i))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mirror the sealer so the round-trip can be asserted in-crate.
    fn seal(plain: &[u8]) -> Vec<u8> {
        let ks = keystream();
        plain
            .iter()
            .enumerate()
            .map(|(i, &b)| b ^ ks[i % SPAN] ^ drift(i))
            .collect()
    }

    #[test]
    fn round_trips() {
        let plain = b"Mozilla/5.0 (Linux; Android 14)";
        assert_eq!(unmask(&seal(plain)), plain);
    }

    #[test]
    fn empty_is_empty() {
        assert!(unmask(&[]).is_empty());
    }
}
