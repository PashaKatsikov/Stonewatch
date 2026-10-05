import 'package:webview_flutter/webview_flutter.dart';

import '../cipher/sealed_values.dart';

// ============================================================
// PAGE TWEAKS — ordered JavaScript enhancers for the WebView
// ============================================================
// Each body is a masked string in sealed_values, decoded at runtime
// and run on every onPageFinished. Every enhancer is written to be
// idempotent (its own window-flag guard), so repeated runs are safe.
//
// Empty bodies are skipped. Until the operator seals project-specific
// bodies, this is a no-op — which is fine: the Flutter-side view
// padding already keeps the WebView out of the camera cutout, and
// partner sites without hardcoded safe-area insets render correctly
// with no injection at all.
//
// Safe-area hard rule (see .cursor/rules/webview_safe_area_injection):
// a viewport body must only reset CSS custom properties and touch
// decorative header classes — never zero padding/margin on
// html/body/#app/#root, or the partner layout collapses.
// ============================================================

abstract final class PageTweaks {
  static Future<void> apply(WebViewController controller) async {
    for (final String body in _ordered()) {
      if (body.isEmpty) continue;
      await controller.runJavaScript(body);
    }
  }

  static List<String> _ordered() => <String>[
        revealJsViewport(),
        revealJsKeyboard(),
        revealJsAutoplay(),
      ];
}
