import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gateway/net/agent_stamp.dart';
import 'gateway/net/gate_query.dart';
import 'gateway/net/install_tracer.dart';
import 'gateway/net/reach_meter.dart';
import 'gateway/push/signal_post.dart';
import 'gateway/store/vault_box.dart';
import 'gateway/traffic_warden.dart';
import 'shell/boot_gate.dart';

// ============================================================
// main.dart — bootstrap wiring
// ============================================================
// Order matters:
//   1. Bindings.
//   2. Firebase + AppCheck in try/catch — the app must run without
//      google-services.json (the warden then stays on the native
//      game), so a failure here can never block startup.
//   3. Edge-to-edge chrome + allow every orientation for the boot /
//      gray surfaces (the game re-locks to portrait on its own).
//   4. AgentStamp.warmUp — forge the UA before any client / WebView.
//   5. VaultBox.prime — load persisted state so the channel decision
//      is synchronous.
//   6. Assemble the gateway and run.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12181E),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await AgentStamp.warmUp();

  final VaultBox vault = VaultBox();
  await vault.prime();

  final ReachMeter reach = ReachMeter();
  final InstallTracer tracer = InstallTracer();
  final GateQuery query = GateQuery(vault);
  final SignalPost signals = SignalPost(vault);

  final TrafficWarden warden = TrafficWarden(
    vault: vault,
    reach: reach,
    tracer: tracer,
    query: query,
    signals: signals,
  );

  runApp(StonewatchApp(warden: warden, vault: vault, signals: signals));
}

class StonewatchApp extends StatelessWidget {
  const StonewatchApp({
    super.key,
    required this.warden,
    required this.vault,
    required this.signals,
  });

  final TrafficWarden warden;
  final VaultBox vault;
  final SignalPost signals;

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
