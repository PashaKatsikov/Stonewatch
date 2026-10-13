//! Authenticated secret vault cipher (XChaCha20-Poly1305).
//!
//! Replaces the previous static-keystream XOR. Every gray-part string
//! (endpoint, attribution key, Firebase options, browser-identity fragments,
//! WebView JS bodies and gray-surface copy) ships only as an AEAD blob in
//! `vault.rs` and is authenticated-decrypted here, at call time — never as a
//! readable literal in `.rodata`, and never recoverable by reversing a
//! trivial XOR tape.
//!
//! Blob layout per sealed value:  `[ 24-byte XNonce | ciphertext | 16-byte tag ]`
//!
//! The shipped library only ever DECRYPTS ([`unmask`]); it carries no RNG.
//! Sealing ([`seal`]) takes a caller-supplied nonce and is used only by the
//! offline `seal_vault` example (host, which sources a fresh random nonce).
//!
//! PER-PROJECT ROTATION (mandatory): the 32-byte key below is unique to this
//! build. Regenerate `K0..K3` + `SALT` for every new project so the vault key
//! family is never shared across sibling apps, then reseal every value.

extern crate alloc;

use alloc::vec::Vec;

use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{Key, XChaCha20Poly1305, XNonce};

/// XChaCha20-Poly1305 nonce length.
pub const NONCE_LEN: usize = 24;
/// Poly1305 authentication tag length.
pub const TAG_LEN: usize = 16;

// ── Project-unique key material ──────────────────────────────────────────
// Split into four chunks + a salt so the raw 32-byte key never sits as one
// contiguous constant in `.rodata`; it is reassembled and avalanched at use.
// Distinct from every sibling build — rotate on each new project.
const K0: [u8; 8] = [0x7E, 0x1C, 0xB4, 0x02, 0xA9, 0x5D, 0xF3, 0x68];
const K1: [u8; 8] = [0x34, 0xD0, 0x91, 0xEE, 0x27, 0x8B, 0x46, 0xC5];
const K2: [u8; 8] = [0xB1, 0x6A, 0x0F, 0x53, 0xDC, 0x9A, 0x71, 0x28];
const K3: [u8; 8] = [0x4D, 0xE7, 0x82, 0x3B, 0x16, 0xCF, 0xA0, 0x5F];
const SALT: [u8; 11] = [
    0x9B, 0x42, 0xD7, 0x6C, 0x18, 0xF5, 0x2A, 0xE0, 0x83, 0x3E, 0xC1,
];

/// Reassemble + avalanche the project key. The AEAD key therefore differs
/// from the four stored chunks, so lifting the chunks verbatim is not enough.
fn project_key() -> [u8; 32] {
    let mut k = [0u8; 32];
    k[0..8].copy_from_slice(&K0);
    k[8..16].copy_from_slice(&K1);
    k[16..24].copy_from_slice(&K2);
    k[24..32].copy_from_slice(&K3);
    let mut i = 0usize;
    while i < 32 {
        k[i] ^= SALT[i % SALT.len()] ^ (i as u8).wrapping_mul(0x1F);
        i += 1;
    }
    k
}

fn cipher() -> XChaCha20Poly1305 {
    XChaCha20Poly1305::new(Key::from_slice(&project_key()))
}

/// Authenticated-decrypt a sealed blob. Empty in -> empty out (the expected
/// state for an unsealed slot, e.g. a JS body). Any blob too short to hold a
/// nonce+tag, or that fails authentication, decodes to an empty vec — a
/// Dart/Rust drift degrades to "" rather than a panic or garbage.
pub fn unmask(blob: &[u8]) -> Vec<u8> {
    if blob.len() < NONCE_LEN + TAG_LEN {
        return Vec::new();
    }
    let (nonce, body) = blob.split_at(NONCE_LEN);
    cipher()
        .decrypt(XNonce::from_slice(nonce), body)
        .unwrap_or_default()
}

/// Seal plaintext into a blob under a caller-supplied 24-byte nonce. Empty
/// plaintext seals to an empty blob so genuinely-empty slots round-trip as
/// `&[]`. Offline-only (the `seal_vault` example): the shipped library never
/// calls this. Panics only if the AEAD itself fails, which cannot happen for
/// a valid key/nonce.
pub fn seal(plain: &[u8], nonce: &[u8; NONCE_LEN]) -> Vec<u8> {
    if plain.is_empty() {
        return Vec::new();
    }
    let ct = cipher()
        .encrypt(XNonce::from_slice(nonce), plain)
        .expect("AEAD seal");
    let mut out = Vec::with_capacity(NONCE_LEN + ct.len());
    out.extend_from_slice(nonce);
    out.extend_from_slice(&ct);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips() {
        let plain = b"Mozilla/5.0 (Linux; Android 14)";
        let nonce = [0x11u8; NONCE_LEN];
        let blob = seal(plain, &nonce);
        assert_eq!(blob.len(), NONCE_LEN + plain.len() + TAG_LEN);
        assert_eq!(unmask(&blob), plain);
    }

    #[test]
    fn empty_round_trips_as_empty() {
        let nonce = [0x22u8; NONCE_LEN];
        assert!(seal(b"", &nonce).is_empty());
        assert!(unmask(&[]).is_empty());
    }

    #[test]
    fn tamper_fails_closed() {
        let nonce = [0x33u8; NONCE_LEN];
        let mut blob = seal(b"secret-endpoint", &nonce);
        // Flip a ciphertext byte: authentication must reject -> empty.
        let last = blob.len() - 1;
        blob[last] ^= 0xFF;
        assert!(unmask(&blob).is_empty());
    }

    #[test]
    fn wrong_nonce_fails_closed() {
        let blob = seal(b"abc", &[0x44u8; NONCE_LEN]);
        let (_, body) = blob.split_at(NONCE_LEN);
        let mut bad = Vec::new();
        bad.extend_from_slice(&[0x45u8; NONCE_LEN]);
        bad.extend_from_slice(body);
        assert!(unmask(&bad).is_empty());
    }
}
