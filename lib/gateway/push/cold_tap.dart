import '../store/vault_box.dart';

// ============================================================
// COLD TAP — one-shot reader for a cold-boot push URL
// ============================================================
// A cold-start push tap arrives through the launch intent, which
// Firebase surfaces via getInitialMessage(); SignalPost stashes it
// in the vault. This is the single read point the warden uses, so
// cold-launch and returning-launch URL handling stay symmetric.
// ============================================================

abstract final class ColdTap {
  /// Reads and clears the stashed cold-boot URL, or null if none.
  static Future<String?> take(VaultBox vault) => vault.takeColdUrl();
}
