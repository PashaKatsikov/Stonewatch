import 'dart:async';
import 'dart:io';

import 'config/settings.dart';
import 'model/outcome.dart';
import 'net/query.dart';
import 'net/attribution.dart';
import 'net/reachability.dart';
import 'push/messaging.dart';
import 'store/prefs_store.dart';

// ============================================================
// TRAFFIC WARDEN — the one place routing is decided
// ============================================================
// `resolve()` returns a single RouteOutcome. The boot surface
// switches on it and only then pushes a route. The decision branches
// on the persisted ChannelMemory and the live state:
//
//   idle (first launch)
//     • no adapter / DNS fails → NoSignalOutcome(wasNative:false)
//     • reply grants a URL     → remember web  → WebOutcome(url)
//     • reply denies           → remember native → NativeOutcome
//
//   web (was in the WebView)
//     • cold-push URL          → WebOutcome(url, fromColdPush:true)
//     • fresh cached URL       → WebOutcome(cached)
//     • reply grants           → WebOutcome(fresh)
//     • reply denies + cache   → WebOutcome(cached)  (last-known-good)
//     • otherwise              → NoSignalOutcome(wasNative:false)
//
//   native (was in the game)
//     • no adapter             → NativeOutcome       (never blocks)
//     • reply grants           → remember web → WebOutcome(url)
//     • otherwise              → NativeOutcome
//
// Concurrent calls share one in-flight future so a double boot-build
// never fires two verdict POSTs. The cache clears on completion, so a
// retry from the no-signal screen re-runs the pipeline in full.
// ============================================================

class LinkRouter {
  LinkRouter({
    required this.vault,
    required this.reach,
    required this.tracer,
    required this.query,
    required this.signals,
  });

  final PrefsStore vault;
  final Reachability reach;
  final Attribution tracer;
  final ConfigQuery query;
  final Messaging signals;

  Future<RouteOutcome>? _pending;

  Future<RouteOutcome> resolve({void Function(double)? onProgress}) {
    return _pending ??= _run(onProgress ?? (_) {})
        .whenComplete(() => _pending = null);
  }

  Future<RouteOutcome> _run(void Function(double) tick) async {
    if (!AppSettings.linksArmed) {
      tick(1);
      return const NativeOutcome();
    }

    signals.onTokenRotated = _onTokenRotated;

    // A cold-launch push tap always wins and is handled on THIS launch: the
    // URL is read from the launch intent (no network, no stash), opened now
    // and never cached — a later icon launch falls through to the config URL.
    final String? pushUrl = await signals.launchPushUrl();
    if (pushUrl != null && pushUrl.isNotEmpty) {
      await vault.rememberChannel(ChannelMemory.web);
      unawaited(_backgroundRefresh());
      tick(1);
      return WebOutcome(pushUrl, fromColdPush: true);
    }

    tick(0.18);
    return switch (vault.channel) {
      ChannelMemory.idle => _firstLaunch(tick),
      ChannelMemory.web => _returningWeb(tick),
      ChannelMemory.native => _returningNative(tick),
    };
  }

  Future<RouteOutcome> _firstLaunch(void Function(double) tick) async {
    if (!await reach.hasAdapter()) {
      return const NoSignalOutcome(wasNative: false);
    }
    tick(0.32);
    await _safely(signals.ignite);
    if (!await reach.canReachOut()) {
      return const NoSignalOutcome(wasNative: false);
    }
    tick(0.52);
    await tracer.ignite();
    await tracer.settle(installWait: AppSettings.firstInstallWait);
    tick(0.78);
    final ServerReply reply = await _askVerdict();
    tick(1);
    if (reply.pointsSomewhere) {
      await vault.rememberChannel(ChannelMemory.web);
      return WebOutcome(reply.url!);
    }
    await vault.rememberChannel(ChannelMemory.native);
    return const NativeOutcome();
  }

  Future<RouteOutcome> _returningWeb(void Function(double) tick) async {
    if (!await reach.hasAdapter()) {
      return const NoSignalOutcome(wasNative: false);
    }
    final String? cached = await vault.cachedDestination();
    if (cached != null && !vault.cachedDestinationStale) {
      tick(1);
      return WebOutcome(cached);
    }

    await Future.wait<void>(<Future<void>>[
      _safely(signals.ignite),
      tracer.ignite(),
    ]);
    if (!await reach.canReachOut()) {
      if (cached != null) return WebOutcome(cached);
      return const NoSignalOutcome(wasNative: false);
    }
    tick(0.58);
    await tracer.settle(installWait: AppSettings.returningInstallWait);
    final ServerReply reply = await _askVerdict();
    tick(1);
    if (reply.pointsSomewhere) return WebOutcome(reply.url!);
    if (cached != null) return WebOutcome(cached);
    return const NoSignalOutcome(wasNative: false);
  }

  Future<RouteOutcome> _returningNative(void Function(double) tick) async {
    if (!await reach.hasAdapter()) {
      tick(1);
      return const NativeOutcome();
    }
    await Future.wait<void>(<Future<void>>[
      _safely(signals.ignite),
      tracer.ignite(),
    ]);
    if (!await reach.canReachOut()) {
      tick(1);
      return const NativeOutcome();
    }
    tick(0.6);
    await tracer.settle(installWait: AppSettings.returningInstallWait);
    final ServerReply reply = await _askVerdict();
    tick(1);
    if (!reply.pointsSomewhere) return const NativeOutcome();
    await vault.rememberChannel(ChannelMemory.web);
    return WebOutcome(reply.url!);
  }

  Future<ServerReply> _askVerdict({String? token}) async {
    final Map<String, dynamic> body = await tracer.composeBody(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? signals.token,
    );
    return query.ask(body);
  }

  Future<void> _backgroundRefresh() async {
    try {
      await Future.wait<void>(<Future<void>>[
        _safely(signals.ignite),
        tracer.ignite(),
      ]);
      await tracer.settle(installWait: AppSettings.returningInstallWait);
      await _askVerdict();
    } catch (_) {}
  }

  Future<void> _onTokenRotated(String token) async {
    try {
      await _askVerdict(token: token);
    } catch (_) {}
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
