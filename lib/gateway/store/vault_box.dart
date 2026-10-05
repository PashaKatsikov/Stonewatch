import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/gate_settings.dart';
import '../model/route_outcome.dart';

// ============================================================
// VAULT BOX — persisted gateway state
// ============================================================
// Flags, timestamps and the channel memory live in SharedPreferences;
// URLs (the cached destination and the one-shot push URL) live in the
// platform's encrypted secure storage.
//
// Every key name is opaque and prefixed with a short random token, so
// a prefs dump reveals no intent. The prefix is unique to this build.
// ============================================================

/// Short random prefix, unrelated to the app slug. Unique per build.
const String _tag = 'sw7_';

class VaultBox {
  VaultBox({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kChannel = '${_tag}ch';
  static const String _kDest = '${_tag}d';
  static const String _kDestTtl = '${_tag}d_ttl';
  static const String _kNotifyUntil = '${_tag}n_until';
  static const String _kNotifyOk = '${_tag}n_ok';
  static const String _kNotifyHardNo = '${_tag}n_hardno';
  static const String _kColdUrl = '${_tag}cold';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Channel memory ─────────────────────────────────────
  ChannelMemory get channel => ChannelMemory.read(_prefs.getString(_kChannel));

  Future<void> rememberChannel(ChannelMemory value) =>
      _prefs.setString(_kChannel, value.wire);

  // ── Cached destination (secure) ────────────────────────
  Future<String?> cachedDestination() => _secure.read(key: _kDest);

  Future<void> cacheDestination(String url, int? expiresUnix) async {
    await _secure.write(key: _kDest, value: url);
    final int ttl = expiresUnix ??
        _now() + GateSettings.cachedUrlLifetime.inSeconds;
    await _prefs.setInt(_kDestTtl, ttl);
  }

  bool get cachedDestinationStale {
    final int? until = _prefs.getInt(_kDestTtl);
    return until == null || _now() >= until;
  }

  // ── Notify-invite state ────────────────────────────────
  bool get notifyGranted => _prefs.getBool(_kNotifyOk) ?? false;

  Future<void> setNotifyGranted(bool value) =>
      _prefs.setBool(_kNotifyOk, value);

  bool get notifyHardDenied => _prefs.getBool(_kNotifyHardNo) ?? false;

  Future<void> setNotifyHardDenied() =>
      _prefs.setBool(_kNotifyHardNo, true);

  Future<void> snoozeNotifyUntil(int unixSeconds) =>
      _prefs.setInt(_kNotifyUntil, unixSeconds);

  /// Should the notify invite appear before the WebView?
  bool get shouldInviteNotify {
    if (notifyGranted || notifyHardDenied) return false;
    final int? until = _prefs.getInt(_kNotifyUntil);
    return until == null || _now() >= until;
  }

  // ── One-shot cold-push URL (secure) ────────────────────
  Future<void> stashColdUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kColdUrl);
    } else {
      await _secure.write(key: _kColdUrl, value: url);
    }
  }

  Future<String?> takeColdUrl() async {
    final String? url = await _secure.read(key: _kColdUrl);
    if (url != null) await _secure.delete(key: _kColdUrl);
    return url;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
