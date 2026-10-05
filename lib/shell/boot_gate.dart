import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../game/art.dart';
import '../play/play_page.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  SharedPreferences? _prefs;
  var _ready = false;
  var _progress = 0.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final clock = Stopwatch()..start();
    const holdMs = 1800;
    final assets = spriteAssets;
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(assets[i]), context);
      if (!mounted) return;
      final loaded = (i + 1) / assets.length;
      final time = (clock.elapsedMilliseconds / holdMs).clamp(0.0, 1.0);
      setState(() {
        _progress = (loaded * 0.8 + time * 0.2).clamp(0.0, 0.96).toDouble();
      });
    }
    final left = holdMs - clock.elapsedMilliseconds;
    if (left > 0) {
      final from = _progress;
      final steps = (left / 32).ceil().clamp(1, 80).toInt();
      final slice = Duration(milliseconds: left ~/ steps);
      for (var step = 1; step <= steps; step++) {
        if (!mounted) return;
        await Future<void>.delayed(slice);
        if (!mounted) return;
        setState(() => _progress = from + (1 - from) * step / steps);
      }
    } else if (mounted) {
      setState(() => _progress = 1);
    }
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF12181E),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    setState(() {
      _prefs = prefs;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (_ready && prefs != null) return PlayPage(prefs: prefs);
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
                      backgroundColor: Color(0x66000000),
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
