import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../secure/values.dart';

// ============================================================
// AGENT STAMP — the one User-Agent used everywhere
// ============================================================
// Both the HTTP client (`ApiClient`) and the WebView read the
// same stamp from here, so the verdict request and every page load
// present an identical, real-looking Chrome-on-Android UA.
//
// Rules honoured (see .cursor/rules/gray_user_agent.mdc):
//   • Every browser-identity substring is masked in the Rust vault,
//     assembled at runtime — no plaintext UA literal in the binary.
//   • The device fields (release / brand / model / build) come from
//     device_info_plus, so two installs never share a stamp.
//   • The string carries no Dart / Flutter / WebView token and no
//     package id.
//
// GAME THEME CATEGORY: crash (cash-out tower) — the appid/appname
// suffix is intentionally NOT appended.
// ============================================================

class UserAgent {
  UserAgent._();

  static String _value = '';

  /// The assembled stamp. Falls back to a coherent Pixel UA if
  /// [warmUp] has not yet run (should never happen in practice —
  /// `main()` awaits it before the first client/WebView is built).
  static String get value => _value.isEmpty ? _composeFallback() : _value;

  /// Reads the real device identity and assembles the stamp. Call
  /// once from `main()` before any HTTP or WebView work.
  static Future<void> warmUp() async {
    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo d = await probe.androidInfo;
        _value = _composeAndroid(
          release: d.version.release,
          brand: _capitalise(d.brand),
          model: d.model,
          build: d.display.isNotEmpty ? d.display : d.id,
        );
      } else if (Platform.isIOS) {
        final IosDeviceInfo d = await probe.iosInfo;
        _value = _composeIos(d.systemVersion);
      }
    } catch (_) {
      _value = _composeFallback();
    }
  }

  // ── Android assembly ───────────────────────────────────
  static String _composeAndroid({
    required String release,
    required String brand,
    required String model,
    required String build,
  }) {
    final String chrome = _pick(revealChromeBuild(), '150.0.7655.84');
    final String webkit = _pick(revealWebkitBuild(), '537.36');

    final List<String> parts = <String>[
      _pick(revealUaProduct(), _fProduct),
      ' ',
      _pick(revealUaPlatformOpen(), _fPlatformOpen),
      ' $release; $brand $model',
      _pick(revealUaBuildTag(), _fBuildTag),
      build,
      _pick(revealUaPlatformClose(), _fPlatformClose),
      _pick(revealUaEngineTag(), _fEngineTag),
      webkit,
      _pick(revealUaEngineTail(), _fEngineTail),
      _pick(revealUaChromeTag(), _fChromeTag),
      chrome,
      _pick(revealUaSafariTag(), _fSafariTag),
      webkit,
    ];
    return parts.join();
  }

  // ── iOS assembly (cross-project safety) ────────────────
  static String _composeIos(String version) {
    final String cpu = version.replaceAll('.', '_');
    final String webkit = _pick(revealWebkitBuild(), '605.1.15');
    return '${_pick(revealUaProduct(), _fProduct)} '
        '$_fIosOpen$cpu$_fIosClose'
        '${_pick(revealUaEngineTag(), _fEngineTag)}$webkit'
        '${_pick(revealUaEngineTail(), _fEngineTail)}'
        '$_fIosVersionTag$version$_fIosSafariTail$webkit';
  }

  static String _composeFallback() => _composeAndroid(
        release: '14',
        brand: 'Google',
        model: 'Pixel 8',
        build: 'UP1A.231005.007',
      );

  static String _pick(String sealed, String fallback) =>
      sealed.isNotEmpty ? sealed : fallback;

  static String _capitalise(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  // ── Code-unit fallbacks — not greppable identity literals.
  // Only reached if the sealed fragment is also empty.
  static String get _fProduct => String.fromCharCodes(
      const <int>[77, 111, 122, 105, 108, 108, 97, 47, 53, 46, 48]);
  static String get _fPlatformOpen => String.fromCharCodes(const <int>[
        40, 76, 105, 110, 117, 120, 59, 32, 65, 110, 100, 114, 111, 105, 100,
      ]);
  static String get _fBuildTag =>
      String.fromCharCodes(const <int>[32, 66, 117, 105, 108, 100, 47]);
  static String get _fPlatformClose => String.fromCharCode(41);
  static String get _fEngineTag => String.fromCharCodes(const <int>[
        32, 65, 112, 112, 108, 101, 87, 101, 98, 75, 105, 116, 47,
      ]);
  static String get _fEngineTail => String.fromCharCodes(const <int>[
        32, 40, 75, 72, 84, 77, 76, 44, 32, 108, 105, 107, 101, 32, 71, 101,
        99, 107, 111, 41,
      ]);
  static String get _fChromeTag => String.fromCharCodes(
      const <int>[32, 67, 104, 114, 111, 109, 101, 47]);
  static String get _fSafariTag => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);

  static String get _fIosOpen => String.fromCharCodes(const <int>[
        40, 105, 80, 104, 111, 110, 101, 59, 32, 67, 80, 85, 32, 105, 80, 104,
        111, 110, 101, 32, 79, 83, 32,
      ]);
  static String get _fIosClose => String.fromCharCodes(const <int>[
        32, 108, 105, 107, 101, 32, 77, 97, 99, 32, 79, 83, 32, 88, 41,
      ]);
  static String get _fIosVersionTag => String.fromCharCodes(
      const <int>[32, 86, 101, 114, 115, 105, 111, 110, 47]);
  static String get _fIosSafariTail => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 47, 49, 53, 69, 49, 52, 56, 32, 83,
        97, 102, 97, 114, 105, 47,
      ]);
}
