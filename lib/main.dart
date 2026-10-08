import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'online/net/user_agent.dart';
import 'online/net/query.dart';
import 'online/net/attribution.dart';
import 'online/net/reachability.dart';
import 'online/push/firebase_boot.dart';
import 'online/push/messaging.dart';
import 'online/store/prefs_store.dart';
import 'online/router.dart';
import 'shell/boot_gate.dart';

// ============================================================
// main.dart — bootstrap wiring
// ============================================================
// Order matters:
//   1. Bindings.
//   2. Firebase + AppCheck in try/catch — the app must run without
//      google-services.json (the warden then stays on the native
//      game), so a failure here can never block startup.
//   3. Edge-to-edge chrome (both system bars hidden by the Activity, no
//      inset) + allow every orientation for the boot / gray surfaces (the
//      game re-locks to portrait on its own).
//   4. UserAgent.warmUp — forge the UA before any client / WebView.
//   5. PrefsStore.prime — load persisted state so the channel decision
//      is synchronous.
//   6. Assemble the gateway and run.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional: the app must run without google-services.json
  // (the warden then stays on the native game). Initialise it and App Check
  // separately so an App Check failure never masks a working messaging
  // stack, and surface any failure in debug instead of swallowing it —
  // "nothing in the logs" was the previous symptom.
  await _bootFirebase();

  // Edge-to-edge app-wide: the Activity draws under the bars and hides them
  // natively (BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE), so a swipe/IME reveals
  // them transiently WITHOUT adding a layout inset — the only safe area that
  // ever survives is the camera cutout. SOFT_INPUT_ADJUST_NOTHING (set in
  // MainActivity) keeps the keyboard from resizing the window.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await UserAgent.warmUp();

  final PrefsStore vault = PrefsStore();
  await vault.prime();

  final Reachability reach = Reachability();
  final Attribution tracer = Attribution();
  final ConfigQuery query = ConfigQuery(vault);
  final Messaging signals = Messaging(vault);

  final LinkRouter warden = LinkRouter(
    vault: vault,
    reach: reach,
    tracer: tracer,
    query: query,
    signals: signals,
  );

  runApp(StonewatchApp(warden: warden, vault: vault, signals: signals));
}

/// Brings up Firebase + App Check without ever blocking startup.
///
/// `initializeApp` throws when google-services.json is absent (the Google
/// Services Gradle plugin is then skipped and no default options exist) — in
/// that case Firebase stays dormant and the gateway runs the native game. We
/// log the reason in debug so the dormant state is diagnosable rather than
/// invisible. App Check is activated only after a successful core init and in
/// its own guard, so a Play Integrity / attestation failure cannot take the
/// messaging stack down with it.
Future<void> _bootFirebase() async {
  try {
    final FirebaseApp? app = await ensureFirebase();
    if (app == null) {
      if (kDebugMode) {
        debugPrint('[net.firebase] options not sealed; staying dormant');
      }
      return;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[net.firebase] initializeApp skipped: $e');
    }
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[net.firebase] App Check activate failed: $e');
    }
  }
}

class StonewatchApp extends StatelessWidget {
  const StonewatchApp({
    super.key,
    required this.warden,
    required this.vault,
    required this.signals,
  });

  final LinkRouter warden;
  final PrefsStore vault;
  final Messaging signals;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stonewatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE0A106),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12181E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE0A106),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: BootGate(warden: warden, vault: vault, signals: signals),
    );
  }
}
