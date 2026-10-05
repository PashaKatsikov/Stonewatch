import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/gate_settings.dart';

// ============================================================
// REACH METER — adapter check + real DNS reachability
// ============================================================
// `connectivity_plus` on its own lies: a captive portal, a VPN
// interface still coming up, or a dead cell all read as "connected".
// So an adapter check is layered with an actual DNS lookup before
// the pipeline ever commits to the online path.
//
// VPN / Bluetooth / Ethernet all count as live — excluding any of
// them produced false-offline screens for real users.
//
// The probe never touches the partner or the verdict host (that
// would log traffic early and correlate the two). It rotates a pair
// of neutral, cheap-DNS hosts unrelated to either.
// ============================================================

class ReachMeter {
  ReachMeter({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static const List<String> _neutralHosts = <String>[
    'www.google.com',
    'www.wikipedia.org',
  ];

  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  int _cursor = 0;

  /// At least one adapter reports up. Does not resolve DNS.
  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> now =
          await _connectivity.checkConnectivity();
      return now.any(_liveAdapters.contains);
    } catch (_) {
      return false;
    }
  }

  /// True when at least one neutral host resolves within the budget.
  /// Rotates the host so a transiently dead resolver does not stick.
  Future<bool> canReachOut() async {
    if (!await hasAdapter()) return false;
    final Duration budget = GateSettings.reachProbeTimeout;
    final int count = _neutralHosts.length;
    for (int step = 0; step < count; step++) {
      final String host = _neutralHosts[(_cursor + step) % count];
      try {
        final List<InternetAddress> hits =
            await InternetAddress.lookup(host).timeout(budget);
        if (hits.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _cursor = (_cursor + 1) % count;
          return true;
        }
      } catch (_) {
        // next host
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
