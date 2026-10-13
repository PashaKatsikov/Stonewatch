//! Offline vault sealer — the tool the `vault.rs` / `mask.rs` comments point
//! at (replaces the never-shipped `tool/transcode_vault.dart`).
//!
//! Re-seals a plaintext secret into the AEAD `&[u8]` blob that gets pasted
//! into `native/stonewatch_core/src/vault.rs`. Each run picks a fresh random
//! XChaCha20-Poly1305 nonce, so the printed array changes every time but
//! always authenticate-decodes back to the exact bytes here, under THIS
//! build's project-unique key. Reseal after any key rotation.
//!
//! Usage (from `native/stonewatch_core/`):
//!
//!   # one value, named by its vault constant:
//!   cargo run --example seal_vault -- V_DEV_KEY "the-real-appsflyer-key"
//!
//!   # several at once (name value name value ...):
//!   cargo run --example seal_vault -- \
//!     V_DEV_KEY "AF_KEY" \
//!     V_FB_API_KEY "AIza..." \
//!     V_FB_APP_ID "1:834..:android:..." \
//!     V_FB_PROJECT_ID "stonewatch-xxxx" \
//!     V_FB_STORAGE_BUCKET "stonewatch-xxxx.firebasestorage.app" \
//!     V_PROJECT_NUMBER "834002154720"
//!
//! With no args it re-emits every currently sealed slot (handy to diff the
//! vault after a grain rotation). Paste the printed block over the matching
//! `pub const V_… : &[u8] = &[ … ];` in `vault.rs`.

use stonewatch_core::mask;
use stonewatch_core::vault;

fn random_nonce() -> [u8; mask::NONCE_LEN] {
    let mut n = [0u8; mask::NONCE_LEN];
    getrandom::getrandom(&mut n).expect("os entropy");
    n
}

fn emit(name: &str, plain: &[u8]) {
    let sealed = if plain.is_empty() {
        Vec::new()
    } else {
        mask::seal(plain, &random_nonce())
    };
    // Safety re-check: the freshly sealed blob must authenticate-decode back
    // to `plain` under this build's key.
    assert_eq!(mask::unmask(&sealed), plain);

    if sealed.is_empty() {
        println!("pub const {name}: &[u8] = &[];");
        return;
    }
    println!("pub const {name}: &[u8] = &[");
    for chunk in sealed.chunks(12) {
        let row: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X},")).collect();
        println!("    {}", row.join(" "));
    }
    println!("];");
}

/// Every sealed slot, so a no-arg run re-emits the whole vault.
const SLOTS: &[(&str, u32)] = &[
    ("V_VERDICT_URL", 1),
    ("V_GCD_BASE", 2),
    ("V_DEV_KEY", 3),
    ("V_PROJECT_NUMBER", 4),
    ("V_UA_PRODUCT", 10),
    ("V_UA_PLATFORM_OPEN", 11),
    ("V_UA_BUILD_TAG", 12),
    ("V_UA_PLATFORM_CLOSE", 13),
    ("V_UA_ENGINE_TAG", 14),
    ("V_UA_ENGINE_TAIL", 15),
    ("V_UA_CHROME_TAG", 16),
    ("V_UA_SAFARI_TAG", 17),
    ("V_CHROME_BUILD", 18),
    ("V_WEBKIT_BUILD", 19),
    ("V_JS_VIEWPORT", 30),
    ("V_JS_KEYBOARD", 31),
    ("V_JS_AUTOPLAY", 32),
    ("V_JS_SEAT_HOOK", 33),
    ("V_NOTIFY_TITLE", 40),
    ("V_NOTIFY_SUBTITLE", 41),
    ("V_NO_SIGNAL_TITLE", 42),
    ("V_NO_SIGNAL_BODY", 43),
    ("V_LABEL_ACCEPT", 44),
    ("V_LABEL_SKIP", 45),
    ("V_LABEL_RETRY", 46),
    ("V_NOTIFY_SNOOZE_SECONDS", 50),
    ("V_FB_API_KEY", 60),
    ("V_FB_APP_ID", 61),
    ("V_FB_PROJECT_ID", 62),
    ("V_FB_STORAGE_BUCKET", 63),
];

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        eprintln!("// Re-emitting every currently sealed slot:\n");
        for (name, sel) in SLOTS {
            emit(name, &vault::bytes(*sel));
        }
        return;
    }
    if args.len() % 2 != 0 {
        eprintln!("expected NAME VALUE pairs; got an odd number of args");
        std::process::exit(2);
    }
    for pair in args.chunks(2) {
        emit(&pair[0], pair[1].as_bytes());
    }
}
