import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/gate_settings.dart';
import '../net/agent_stamp.dart';
import '../net/reach_meter.dart';
import '../push/signal_post.dart';
import '../store/vault_box.dart';
import '../web/page_tweaks.dart';
import 'no_signal_view.dart';

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

class WebHost extends StatefulWidget {
  const WebHost({
    super.key,
    required this.url,
    required this.vault,
    required this.signals,
  });

  final String url;
  final VaultBox vault;
  final SignalPost signals;

  @override
  State<WebHost> createState() => _WebHostState();
}

class _WebHostState extends State<WebHost> with WidgetsBindingObserver {
  // Unique per build — must match MainActivity.kt → fileGateName.
  static const MethodChannel _fileGate = MethodChannel('stonewatch/filegate');

  late final WebViewController _web;
  bool _busy = true;
  bool _bailed = false;
  String? _lastTop;
  int _loopHits = 0;
  Timer? _dropTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

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

    widget.signals.onUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _netSub = ReachMeter().changes.listen(_onNetChange);
  }

  void _onNetChange(List<ConnectivityResult> states) {
    final bool allDown = states.isNotEmpty &&
        states.every((ConnectivityResult e) => e == ConnectivityResult.none);
    if (!allDown) {
      _dropTimer?.cancel();
      return;
    }
    _dropTimer?.cancel();
    _dropTimer = Timer(GateSettings.reachDropDebounce, _bailToOffline);
  }

  void _goImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
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
      ..setUserAgent(AgentStamp.value)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _loopHits = 0;
          PageTweaks.apply(_web);
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
        _loopHits < GateSettings.redirectLoopRetries) {
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
    if (await ReachMeter().canReachOut()) return;
    _bailToOffline();
  }

  void _bailToOffline() {
    if (_bailed || !mounted) return;
    _bailed = true;
    final String keep = _lastTop ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalView(
          rebuild: (_) => WebHost(
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
    widget.signals.onUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
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
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
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
    );
  }
}
