// ============================================================
// ROUTE OUTCOME — the single result type of the gateway decision
// ============================================================
// `TrafficWarden.resolve()` returns exactly one [RouteOutcome].
// The boot surface destructures it with an exhaustive `switch`, so
// adding a new destination forces every dispatch site to handle it.
// No screen pushes routes on its own guesswork.
// ============================================================

/// Persisted memory of where a returning launch should head first.
///
/// Stored under a project-scoped key in the vault. The wire strings
/// are local-only (never sent to the backend), but keep them stable
/// so an upgrade does not strand existing installs.
enum ChannelMemory {
  idle,
  web,
  native;

  String get wire => switch (this) {
        ChannelMemory.idle => 'idle',
        ChannelMemory.web => 'web',
        ChannelMemory.native => 'native',
      };

  static ChannelMemory read(String? raw) => switch (raw) {
        'web' || 'portal' => ChannelMemory.web,
        'native' || 'game' => ChannelMemory.native,
        _ => ChannelMemory.idle,
      };
}

/// Parsed routing reply from the backend.
///
/// The wire keys `{ok, url, expires, message}` are the backend
/// contract — do not rename them.
class GateReply {
  const GateReply({
    required this.granted,
    this.url,
    this.expiresUnix,
    this.note,
  });

  GateReply.denied(this.note)
      : granted = false,
        url = null,
        expiresUnix = null;

  factory GateReply.parse(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return GateReply(
      granted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresUnix: switch (rawExpiry) {
        final num n => n.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      },
      note: json['message']?.toString(),
    );
  }

  final bool granted;
  final String? url;
  final int? expiresUnix;
  final String? note;

  bool get pointsSomewhere =>
      granted && url != null && url!.isNotEmpty;
}

/// Exhaustive set of boot destinations.
sealed class RouteOutcome {
  const RouteOutcome();
}

/// Show the native Stonewatch game.
final class NativeOutcome extends RouteOutcome {
  const NativeOutcome();
}

/// Open the WebView at [url]. [fromColdPush] shortens the intro when
/// the launch came from tapping a cold-boot push notification.
final class WebOutcome extends RouteOutcome {
  const WebOutcome(this.url, {this.fromColdPush = false});

  final String url;
  final bool fromColdPush;
}

/// Show the no-connection screen. Retry re-runs the whole pipeline.
/// [wasNative] lets a returning game user bounce straight back to the
/// game on retry instead of re-deciding.
final class NoSignalOutcome extends RouteOutcome {
  const NoSignalOutcome({required this.wasNative});

  final bool wasNative;
}
