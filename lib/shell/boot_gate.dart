import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../game/art.dart';
import '../online/model/outcome.dart';
import '../online/push/messaging.dart';
import '../online/store/prefs_store.dart';
import '../online/router.dart';
import '../online/view/offline_screen.dart';
import '../online/view/notify_prompt.dart';
import '../online/view/web_screen.dart';
import '../play/play_page.dart';

// ============================================================
// BOOT GATE — the loading surface that drives the decision
// ============================================================
// Visually unchanged: the Stonewatch loading artwork, the animated
// "loading" caption and the bottom progress bar. Behind it, the
// LinkRouter resolves the route. The progress bar reads the
// warden's progress (0 → 0.9) during the network wait, then fills to
// 1.0 as the next surface takes over — monotonic, never jumping back.
//
//   NativeOutcome   → precache game art, lock portrait, show PlayPage
//   WebOutcome      → NotifyPrompt (first time) or WebScreen
//   NoSignalOutcome → OfflineScreen (retry re-runs this gate)
// ============================================================

class BootGate extends StatefulWidget {
  const BootGate({
    super.key,
    required this.warden,
    required this.vault,
    required this.signals,
  });

  final LinkRouter warden;
  final PrefsStore vault;
  final Messaging signals;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  // The warden reports progress past this point only once it has confirmed a
  // live connection (or committed to the game / a cold-push / cached page).
  // Below it the launch is still deciding — and an offline launch bails to the
  // no-signal screen from here WITHOUT ever showing the loading surface.
  static const double _kRevealGate = 0.5;

  var _progress = 0.0;
  var _game = false;
  var _revealed = false;
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

    // Decode the loading artwork up-front so that, when the surface is
    // revealed, the background paints together with the caption and the
    // progress bar instead of a frame or two later.
    await _warmLoadingArt();
    if (!mounted) return;

    final outcome = await widget.warden.resolve(
      onProgress: (v) {
        if (!mounted) return;
        setState(() {
          _progress = (v * 0.9).clamp(0.0, 0.9);
          if (v >= _kRevealGate) _revealed = true;
        });
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
        if (_revealed) await _ensureMinHold(clock, 900);
        if (!mounted) return;
        setState(() => _progress = 1);
        final Widget next = widget.vault.shouldInviteNotify
            ? NotifyPrompt(
                vault: widget.vault,
                signals: widget.signals,
                destination: url,
              )
            : WebScreen(
                url: url,
                vault: widget.vault,
                signals: widget.signals,
              );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => next),
        );
      case NoSignalOutcome():
        // Offline launches never reached the reveal gate, so the loading
        // surface was never shown — jump straight to the no-signal screen
        // with no artwork, no progress bar and no minimum hold.
        if (_revealed) await _ensureMinHold(clock, 900);
        if (!mounted) return;
        setState(() => _progress = 1);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OfflineScreen(
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

  Future<void> _warmLoadingArt() async {
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    try {
      // Current orientation first (blocking); warm the other one in the
      // background so a rotation during boot stays smooth too.
      await precacheImage(
        AssetImage(landscape ? loadingHorizontalAsset : loadingVerticalAsset),
        context,
      );
      if (!mounted) return;
      unawaited(precacheImage(
        AssetImage(landscape ? loadingVerticalAsset : loadingHorizontalAsset),
        context,
      ));
    } catch (_) {}
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

    // Until the warden clears the reveal gate, keep a bare splash (the sky
    // colour behind the native launch screen) — no loading artwork and no
    // progress bar. An offline launch leaves from here to the no-signal view.
    if (!_revealed) {
      return const Scaffold(backgroundColor: Color(0xFF20A9FA));
    }

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
