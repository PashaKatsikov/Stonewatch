// ============================================================
// BACKDROPS — gateway screen background art paths
// ============================================================
// Portrait / landscape artwork for the gateway surfaces. The
// no-signal screen has no dedicated art, so it reuses the loading
// backdrop with a text panel drawn on top.
// ============================================================

abstract final class Backdrops {
  static const String loadingPortrait = 'assets/loading/vertical.webp';
  static const String loadingLandscape = 'assets/loading/horizontal.webp';

  static const String notifyPortrait = 'assets/notifications/vertical.webp';
  static const String notifyLandscape = 'assets/notifications/horizontal.webp';

  // No-signal reuses the loading art.
  static const String noSignalPortrait = loadingPortrait;
  static const String noSignalLandscape = loadingLandscape;
}
