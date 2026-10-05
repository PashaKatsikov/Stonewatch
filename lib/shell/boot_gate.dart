import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../game/art.dart';
import '../gateway/model/route_outcome.dart';
import '../gateway/push/signal_post.dart';
import '../gateway/store/vault_box.dart';
import '../gateway/traffic_warden.dart';
import '../gateway/view/no_signal_view.dart';
import '../gateway/view/notify_invite.dart';
import '../gateway/view/web_host.dart';
import '../play/play_page.dart';

// ============================================================
// BOOT GATE — the loading surface that drives the decision
// ============================================================
// Visually unchanged: the Stonewatch loading artwork, the animated
// "loading" caption and the bottom progress bar. Behind it, the
// TrafficWarden resolves the route. The progress bar reads the
// warden's progress (0 → 0.9) during the network wait, then fills to
// 1.0 as the next surface takes over — monotonic, never jumping back.
//
//   NativeOutcome   → precache game art, lock portrait, show PlayPage
//   WebOutcome      → NotifyInvite (first time) or WebHost
//   NoSignalOutcome → NoSignalView (retry re-runs this gate)
// ============================================================

class BootGate extends StatefulWidget {
  const BootGate({
    super.key,
    required this.warden,
    required this.vault,
    required this.signals,
  });

  final TrafficWarden warden;
  final VaultBox vault;
  final SignalPost signals;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  var _progress = 0.0;
  var _game = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0x00000000),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  Future<void> _drive() async {
    final clock = Stopwatch()..start();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final outcome = await widget.warden.resolve(
      onProgress: (v) {
        if (mounted) setState(() => _progress = (v * 0.9).clamp(0.0, 0.9));
      },
    );
    if (!mounted) return;

    switch (outcome) {
      case NativeOutcome():
        await _warmGameArt();
        await _ensureMinHold(clock, 1500);
        if (!mounted) return;
        setState(() => _progress = 1);
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
        _restoreGameChrome();
        if (!mounted) return;
        setState(() {
          _prefs = prefs;
          _game = true;
        });
      case WebOutcome(url: final url):
        await _ensureMinHold(clock, 900);
        if (!mounted) return;
        setState(() => _progress = 1);
        final Widget next = widget.vault.shouldInviteNotify
            ? NotifyInvite(
                vault: widget.vault,
                signals: widget.signals,
                destination: url,
              )
            : WebHost(
                url: url,
                vault: widget.vault,
                signals: widget.signals,
              );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => next),
        );
      case NoSignalOutcome():
        await _ensureMinHold(clock, 900);
        if (!mounted) return;
        setState(() => _progress = 1);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NoSignalView(
              rebuild: (_) => BootGate(
                warden: widget.warden,
                vault: widget.vault,
                signals: widget.signals,
              ),
            ),
          ),
        );
    }
  }

  Future<void> _warmGameArt() async {
    final assets = spriteAssets;
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(assets[i]), context);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _progress = 0.9 + 0.1 * (i + 1) / assets.length);
    }
  }

  Future<void> _ensureMinHold(Stopwatch clock, int minMs) async {
    final left = minMs - clock.elapsedMilliseconds;
    if (left > 0) {
      await Future<void>.delayed(Duration(milliseconds: left));
    }
  }

  void _restoreGameChrome() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF12181E),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (_game && prefs != null) return PlayPage(prefs: prefs);

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF20A9FA),
      body: MediaQuery(
        data: MediaQuery.of(context).removePadding(
          removeLeft: true,
          removeRight: true,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              landscape ? loadingHorizontalAsset : loadingVerticalAsset,
              fit: BoxFit.cover,
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: padding.bottom + 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'loading',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      height: 1,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0xCC000000), offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: const Color(0x66000000),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
