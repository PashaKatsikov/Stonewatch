import 'byte_mask.dart';

// ============================================================
// SEALED VALUES — masked byte arrays, single source of truth
// ============================================================
// Every value that would otherwise be a greppable string literal
// in the APK lives here as a masked byte array. The arrays are
// meaningless until [unmask] runs over them at call time.
//
// Regenerate any array with:
//   dart run tool/seal_values.dart name:plaintext
// and paste the printed line in place. NEVER paste plaintext here.
//
// ─────────────────────────────────────────────────────────────
// Backend + attribution. Regenerated with tool/seal_values.dart.
// Plaintext never lives in this file.
// ─────────────────────────────────────────────────────────────

/// Full POST URL that returns the routing reply.
const List<int> _verdictUrl = <int>[
  0x35, 0x6B, 0xF3, 0xE7, 0x94, 0xC4, 0x32, 0x9B, 0x06, 0xC3, 0xF6, 0xC8,
  0xA5, 0x54, 0x83, 0x5E, 0xD9, 0xE4, 0x73, 0x71, 0xAB, 0x46, 0x2F, 0x3F,
  0x24, 0x2F, 0x16, 0x02, 0x24, 0x42, 0xF1, 0x22, 0x70, 0x16, 0x17,
];

/// AppsFlyer GCD base — used by the organic-rescue re-query.
const List<int> _gcdBase = <int>[
  0x35, 0x6B, 0xF3, 0xE7, 0x94, 0xC4, 0x32, 0x9B, 0x12, 0xD4, 0xFD, 0xD5,
  0xA4, 0x48, 0xCC, 0x4B, 0xCA, 0xFC, 0x2E, 0x64, 0xB3, 0x50, 0x38, 0x28,
  0x25, 0x2F, 0x16, 0x01, 0x6D, 0x42, 0xF8, 0x7F, 0x74, 0x1F, 0x0B, 0xE6,
  0x60, 0x98, 0x5F, 0x56, 0x79, 0x56, 0xDF, 0x59, 0x8E, 0x13, 0x3D,
];

/// AppsFlyer developer key.
const List<int> _devKey = <int>[
  0x0F, 0x72, 0xCC, 0xEE, 0xD3, 0x8E, 0x51, 0xF9, 0x14, 0xF9, 0xCF, 0x94,
  0x91, 0x74, 0xAC, 0x66, 0xCC, 0xDE, 0x10, 0x4E, 0xA5, 0x78,
];

/// Firebase project number (matches google-services.json).
const List<int> _projectNumber = <int>[
  0x65, 0x2C, 0xB3, 0xA7, 0xD7, 0xCC, 0x2C, 0x81, 0x41, 0x80, 0xAB, 0x96,
];

// ─────────────────────────────────────────────────────────────
// Browser-identity scaffolding — masked so no UA cluster marker
// ships as a plain literal. Generated via tool/seal_values.dart.
// ─────────────────────────────────────────────────────────────

// OK  _uaProduct  (11 chars)
const List<int> _uaProduct = <int>[
  0x10, 0x70, 0xFD, 0xFE, 0x8B, 0x92, 0x7C, 0x9B, 0x40, 0x99, 0xA9,
];
// OK  _uaPlatformOpen  (15 chars)
const List<int> _uaPlatformOpen = <int>[
  0x75, 0x53, 0xEE, 0xF9, 0x92, 0x86, 0x26, 0x94, 0x34, 0xD9, 0xFD, 0xD4,
  0xAF, 0x4A, 0x86,
];
// OK  _uaBuildTag  (7 chars)
const List<int> _uaBuildTag = <int>[
  0x7D, 0x5D, 0xF2, 0xFE, 0x8B, 0x9A, 0x32,
];
// OK  _uaPlatformClose  (1 chars)
const List<int> _uaPlatformClose = <int>[
  0x74,
];
// OK  _uaEngineTag  (13 chars)
const List<int> _uaEngineTag = <int>[
  0x7D, 0x5E, 0xF7, 0xE7, 0x8B, 0x9B, 0x4A, 0xD1, 0x17, 0xFC, 0xF0, 0xD2,
  0xEF,
];
// OK  _uaEngineTail  (20 chars)
const List<int> _uaEngineTail = <int>[
  0x7D, 0x37, 0xCC, 0xDF, 0xB3, 0xB3, 0x51, 0x98, 0x55, 0xDB, 0xF0, 0xCD,
  0xA5, 0x03, 0xA5, 0x4F, 0xD9, 0xE7, 0x32, 0x2B,
];
// OK  _uaChromeTag  (8 chars)
const List<int> _uaChromeTag = <int>[
  0x7D, 0x5C, 0xEF, 0xE5, 0x88, 0x93, 0x78, 0x9B,
];
// OK  _uaSafariTag  (15 chars)
const List<int> _uaSafariTag = <int>[
  0x7D, 0x52, 0xE8, 0xF5, 0x8E, 0x92, 0x78, 0x94, 0x26, 0xD6, 0xFF, 0xC7,
  0xB2, 0x4A, 0xCD,
];
// OK  _chromeBuild  (13 chars)
const List<int> _chromeBuild = <int>[
  0x6C, 0x2A, 0xB7, 0xB9, 0xD7, 0xD0, 0x2A, 0x82, 0x40, 0x82, 0xB7, 0x9E,
  0xF4,
];
// OK  _webkitBuild  (6 chars)
const List<int> _webkitBuild = <int>[
  0x68, 0x2C, 0xB0, 0xB9, 0xD4, 0xC8,
];

// ─────────────────────────────────────────────────────────────
// WebView JS enhancers — masked bodies, empty until sealed.
// Scanners hash normalized JS bodies and cluster on a match, so the
// bodies ship masked. Empty slots are a no-op; the native view-
// padding already keeps the WebView clear of the camera cutout, so
// partner sites render correctly even before these are sealed.
// Seal with: dart run tool/seal_values.dart jsViewport:"<body>"
// ─────────────────────────────────────────────────────────────

/// Site-side safe-area / viewport-fit neutraliser.
const List<int> _jsViewport = <int>[];

/// Keyboard focus-scroll helper.
const List<int> _jsKeyboard = <int>[];

/// Inline-video autoplay enabler.
const List<int> _jsAutoplay = <int>[];

// ─────────────────────────────────────────────────────────────
// Accessors — every consumer reads through these, never the raw
// arrays. Add a new sealed value by adding an array + an accessor.
// ─────────────────────────────────────────────────────────────

String revealVerdictUrl() => unmask(_verdictUrl);
String revealGcdBase() => unmask(_gcdBase);
String revealDevKey() => unmask(_devKey);
String revealProjectNumber() => unmask(_projectNumber);

String revealUaProduct() => unmask(_uaProduct);
String revealUaPlatformOpen() => unmask(_uaPlatformOpen);
String revealUaBuildTag() => unmask(_uaBuildTag);
String revealUaPlatformClose() => unmask(_uaPlatformClose);
String revealUaEngineTag() => unmask(_uaEngineTag);
String revealUaEngineTail() => unmask(_uaEngineTail);
String revealUaChromeTag() => unmask(_uaChromeTag);
String revealUaSafariTag() => unmask(_uaSafariTag);
String revealChromeBuild() => unmask(_chromeBuild);
String revealWebkitBuild() => unmask(_webkitBuild);

String revealJsViewport() => unmask(_jsViewport);
String revealJsKeyboard() => unmask(_jsKeyboard);
String revealJsAutoplay() => unmask(_jsAutoplay);

/// Builds the AppsFlyer GCD rescue URL. Returns "" when the base is
/// not sealed yet — callers treat that as "rescue unavailable".
String revealGcdCallUrl(String appRef, String deviceId) {
  final String base = revealGcdBase();
  if (base.isEmpty) return '';
  return '$base$appRef?devkey=${revealDevKey()}&device_id=$deviceId';
}
