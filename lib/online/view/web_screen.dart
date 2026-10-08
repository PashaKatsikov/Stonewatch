import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/settings.dart';
import '../net/user_agent.dart';
import '../net/reachability.dart';
import '../push/messaging.dart';
import '../store/prefs_store.dart';
import '../web/page_tweaks.dart';
import 'offline_screen.dart';

// ============================================================
// WEB HOST — the WebView surface (gray content)
// ============================================================
// Hosts the destination URL with the forged UA, both orientations,
// immersive chrome, external-scheme hand-off, redirect-loop recovery,
// a debounced live-connectivity guard, warm-push URL delivery, the
// native file chooser (over a MethodChannel, no file_picker dep), and
// the PageTweaks JS bundle.
//
// The WebView carries NO site classification: there is no deposit /
// cashier / register regex and no funnel emission. Any funnel lives
// server-side; this is a dumb shell.
//
// The camera cutout is respected by padding with viewPadding on both
// axes (gray_part_pitfalls §14). No SafeArea wrapper — the padding is
// explicit so the bottom edge is never needlessly inset.
// ============================================================

class WebScreen extends StatefulWidget {
  const WebScreen({
    super.key,
    required this.url,
    required this.vault,
    required this.signals,
  });

  final String url;
  final PrefsStore vault;
  final Messaging signals;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> with WidgetsBindingObserver {
  // Unique per build — must match MainActivity.kt → fileGateName.
  static const MethodChannel _fileGate = MethodChannel('sw/upload');
  // Carries the live display-cutout + IME metrics from the Activity. The IME
  // height drives the in-page field lift; the cutout drives the only padding
  // the WebView ever gets. Must match MainActivity.kt → surfaceName.
  static const MethodChannel _surface = MethodChannel('sw/metrics');

  late final WebViewController _web;
  bool _busy = true;
  bool _bailed = false;
  String? _lastTop;
  int _loopHits = 0;
  Timer? _dropTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  // Camera-cutout inset (never the nav bar) cached per orientation so a
  // rotation applies the final padding in one step instead of settling over
  // several frames; keyed by isLandscape. Plus the current keyboard height.
  // Both in logical pixels, sourced from the native insets channel.
  final Map<bool, EdgeInsets> _cutByLand = <bool, EdgeInsets>{};
  double _imeLift = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _goImmersive();
    _spinUp();

    // Native pushes a fresh sample whenever the keyboard animates or the
    // configuration changes; we also pull once per frame-metrics change.
    _surface.setMethodCallHandler(_onSurface);
    WidgetsBinding.instance.addPostFrameCallback((_) => _gauge());

    widget.signals.onUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _netSub = Reachability().changes.listen(_onNetChange);
  }

  @override
  void didChangeMetrics() => _gauge();

  Future<dynamic> _onSurface(MethodCall call) async {
    if (call.method == 'insetPulse') {
      final Object? raw = call.arguments;
      if (raw is Map) await _absorb(Map<Object?, Object?>.from(raw));
    }
    return null;
  }

  /// Pulls one metrics sample from the Activity. Falls back to the engine's
  /// own view insets if the channel is unavailable (e.g. hot path before the
  /// handler is wired), so the field still lifts.
  Future<void> _gauge() async {
    if (!mounted) return;
    try {
      final Object? native = await _surface.invokeMethod<Object>('probeInsets');
      if (native is Map) {
        await _absorb(Map<Object?, Object?>.from(native));
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    final view = View.of(context);
    await PageTweaks.seat(_web, view.viewInsets.bottom / view.devicePixelRatio);
  }

  /// Applies a native metrics sample: caches the cutout under the orientation
  /// it was measured in (so a later rotation to that orientation is instant),
  /// and when the IME height moves meaningfully, hands it to the lift helper.
  Future<void> _absorb(Map<Object?, Object?> sample) async {
    if (!mounted) return;
    final bool land = sample['land'] == true;
    final EdgeInsets cut = EdgeInsets.only(
      left: (sample['cutL'] as num?)?.toDouble() ?? 0,
      top: (sample['cutT'] as num?)?.toDouble() ?? 0,
      right: (sample['cutR'] as num?)?.toDouble() ?? 0,
    );
    if (_cutByLand[land] != cut) {
      setState(() => _cutByLand[land] = cut);
    }

    final double ime = (sample['ime'] as num?)?.toDouble() ?? 0;
    if ((ime - _imeLift).abs() < 1) return;
    _imeLift = ime;
    await PageTweaks.seat(_web, ime);
  }

  void _onNetChange(List<ConnectivityResult> states) {
    final bool allDown = states.isNotEmpty &&
        states.every((ConnectivityResult e) => e == ConnectivityResult.none);
    if (!allDown) {
      _dropTimer?.cancel();
      return;
    }
    _dropTimer?.cancel();
    _dropTimer = Timer(AppSettings.reachDropDebounce, _bailToOffline);
  }

  void _goImmersive() {
    // Edge-to-edge: the Activity draws under both bars and keeps the window
    // from resizing/panning for the IME (SOFT_INPUT_ADJUST_NOTHING). The
    // native side hides the bars (showing only the nav bar transiently while
    // the keyboard is up, overlaid, never inset), so the WebView is padded by
    // the camera cutout alone and the field lift is driven by JS — identical
    // behaviour in portrait and landscape.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _goImmersive();
  }

  void _spinUp() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(UserAgent.value)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _loopHits = 0;
          PageTweaks.apply(_web).whenComplete(() {
            // Re-seat against the live keyboard height once the enhancers
            // (including the lift helper) are installed on the new document.
            _imeLift = 0;
            _gauge();
          });
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;
    final String blurb = err.description.toLowerCase();

    final bool loop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (loop &&
        _lastTop != null &&
        _loopHits < AppSettings.redirectLoopRetries) {
      _loopHits++;
      _web.loadRequest(Uri.parse(_lastTop!));
      return;
    }

    // Cover the native error page right away.
    if (mounted) setState(() => _busy = true);

    final bool netGone = blurb.contains('name_not_resolved') ||
        blurb.contains('address_unreachable') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (netGone) {
      _bailToOffline();
    } else {
      _bailIfReallyDown();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastTop = req.url;
      return NavigationDecision.navigate;
    }
    _handOff(uri);
    return NavigationDecision.prevent;
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController platform =
        _web.platform as AndroidWebViewController;

    platform.setMediaPlaybackRequiresUserGesture(false);
    platform.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    platform.setOnShowFileSelector(_chooseFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(platform, true);
  }

  Future<List<String>> _chooseFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _fileGate.invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      return picked?.whereType<String>().toList() ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handOff(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _bailIfReallyDown() async {
    if (_bailed) return;
    if (await Reachability().canReachOut()) return;
    _bailToOffline();
  }

  void _bailToOffline() {
    if (_bailed || !mounted) return;
    _bailed = true;
    final String keep = _lastTop ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineScreen(
          rebuild: (_) => WebScreen(
            url: keep,
            vault: widget.vault,
            signals: widget.signals,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropTimer?.cancel();
    _netSub?.cancel();
    _surface.setMethodCallHandler(null);
    widget.signals.onUrl = null;
    // Hand back to the game edge-to-edge; the Activity keeps the bars hidden.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      // Strip the IME inset from the subtree so nothing in it reacts to the
      // keyboard: the window never resizes (SOFT_INPUT_ADJUST_NOTHING) and the
      // field is lifted in-page instead, uniformly in both orientations.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Padding(
                // The camera cutout is the only safe area; the nav bar (hidden,
                // or transient over the keyboard) never contributes an inset.
                // Read from the per-orientation cache so rotation is instant.
                padding: _cutByLand[landscape] ?? EdgeInsets.zero,
                child: WebViewWidget(controller: _web),
              ),
              if (_busy && !landscape)
                const ColoredBox(
                  color: Color(0x80000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFFC94D)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
