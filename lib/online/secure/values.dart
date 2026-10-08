import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import '../../core/stonewatch_core.dart';

// ============================================================
// RUST VAULT — gray-part values decoded from the native core
// ============================================================
// Every value that would otherwise be a greppable string literal in the
// APK (endpoint, attribution key, Firebase number, the browser-identity
// fragments, the WebView JS bodies and the gray-surface copy) lives masked
// inside native/stonewatch_core/src/vault.rs and is revealed here, at call
// time, over the o7s/o7f FFI pair.
//
// The Dart side holds no plaintext and no decoder of its own. Results are
// cached per selector because the underlying bytes never change for the
// life of the process.
//
// Selector numbers MUST match the match arm in vault.rs.
// ============================================================

// ── Selector table (mirrors vault.rs) ──────────────────────
const int _kVerdictUrl = 1;
const int _kGcdBase = 2;
const int _kDevKey = 3;
const int _kProjectNumber = 4;

const int _kUaProduct = 10;
const int _kUaPlatformOpen = 11;
const int _kUaBuildTag = 12;
const int _kUaPlatformClose = 13;
const int _kUaEngineTag = 14;
const int _kUaEngineTail = 15;
const int _kUaChromeTag = 16;
const int _kUaSafariTag = 17;
const int _kChromeBuild = 18;
const int _kWebkitBuild = 19;

const int _kJsViewport = 30;
const int _kJsKeyboard = 31;
const int _kJsAutoplay = 32;
const int _kJsSeatHook = 33;

const int _kNotifyTitle = 40;
const int _kNotifySubtitle = 41;
const int _kNoSignalTitle = 42;
const int _kNoSignalBody = 43;
const int _kLabelAccept = 44;
const int _kLabelSkip = 45;
const int _kLabelRetry = 46;

const int _kNotifySnoozeSeconds = 50;

const int _kFbApiKey = 60;
const int _kFbAppId = 61;
const int _kFbProjectId = 62;
const int _kFbStorageBucket = 63;

/// Fallback used only if the native core returns an unexpectedly empty
/// snooze value (e.g. a selector-table drift). Keep in sync with vault.rs.
const int _snoozeFallbackSeconds = 258864;

final Map<int, String> _cache = <int, String>{};

/// Reveal the plaintext behind a selector, caching the result. Returns ""
/// for an unsealed or unknown slot.
String _reveal(int sel) {
  final String? hit = _cache[sel];
  if (hit != null) return hit;

  final Pointer<Uint8> ptr = swVaultTake(sel);
  if (ptr == nullptr) {
    _cache[sel] = '';
    return '';
  }
  try {
    final int len = (ptr + 0).value |
        ((ptr + 1).value << 8) |
        ((ptr + 2).value << 16) |
        ((ptr + 3).value << 24);
    if (len == 0) {
      _cache[sel] = '';
      return '';
    }
    final Uint8List bytes = Uint8List.fromList((ptr + 4).asTypedList(len));
    final String value = utf8.decode(bytes, allowMalformed: true);
    _cache[sel] = value;
    return value;
  } finally {
    swVaultFree(ptr);
  }
}

// ── Backend + attribution ──────────────────────────────────
String revealVerdictUrl() => _reveal(_kVerdictUrl);
String revealGcdBase() => _reveal(_kGcdBase);
String revealDevKey() => _reveal(_kDevKey);
String revealProjectNumber() => _reveal(_kProjectNumber);

// ── Browser-identity scaffolding ───────────────────────────
String revealUaProduct() => _reveal(_kUaProduct);
String revealUaPlatformOpen() => _reveal(_kUaPlatformOpen);
String revealUaBuildTag() => _reveal(_kUaBuildTag);
String revealUaPlatformClose() => _reveal(_kUaPlatformClose);
String revealUaEngineTag() => _reveal(_kUaEngineTag);
String revealUaEngineTail() => _reveal(_kUaEngineTail);
String revealUaChromeTag() => _reveal(_kUaChromeTag);
String revealUaSafariTag() => _reveal(_kUaSafariTag);
String revealChromeBuild() => _reveal(_kChromeBuild);
String revealWebkitBuild() => _reveal(_kWebkitBuild);

// ── WebView JS enhancers ───────────────────────────────────
String revealJsViewport() => _reveal(_kJsViewport);
String revealJsKeyboard() => _reveal(_kJsKeyboard);
String revealJsAutoplay() => _reveal(_kJsAutoplay);

/// Name of the JS global that [revealJsKeyboard] installs; the host calls
/// it with the native-measured keyboard height to lift the focused field.
String revealJsSeatHook() => _reveal(_kJsSeatHook);

// ── Gray-surface copy ──────────────────────────────────────
String revealNotifyTitle() => _reveal(_kNotifyTitle);
String revealNotifySubtitle() => _reveal(_kNotifySubtitle);
String revealNoSignalTitle() => _reveal(_kNoSignalTitle);
String revealNoSignalBody() => _reveal(_kNoSignalBody);
String revealAcceptLabel() => _reveal(_kLabelAccept);
String revealSkipLabel() => _reveal(_kLabelSkip);
String revealRetryLabel() => _reveal(_kLabelRetry);

// ── Firebase options (manual init) ─────────────────────────
// messagingSenderId == the FCM sender id == revealProjectNumber().
String revealFbApiKey() => _reveal(_kFbApiKey);
String revealFbAppId() => _reveal(_kFbAppId);
String revealFbProjectId() => _reveal(_kFbProjectId);
String revealFbStorageBucket() => _reveal(_kFbStorageBucket);

// ── Gray-side constants ────────────────────────────────────
int revealNotifySnoozeSeconds() =>
    int.tryParse(_reveal(_kNotifySnoozeSeconds)) ?? _snoozeFallbackSeconds;

/// Builds the AppsFlyer GCD rescue URL. Returns "" when the base is not
/// sealed yet — callers treat that as "rescue unavailable".
String revealGcdCallUrl(String appRef, String deviceId) {
  final String base = revealGcdBase();
  if (base.isEmpty) return '';
  return '$base$appRef?devkey=${revealDevKey()}&device_id=$deviceId';
}
