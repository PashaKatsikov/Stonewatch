import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'agent_stamp.dart';

// ============================================================
// STAMPED CLIENT — HTTP wrapper that always carries the stamp
// ============================================================
// Composition over the raw http.Client (not a BaseClient subclass):
// a tiny facade that merges the forged User-Agent into every call's
// headers. This keeps the default `dart-io/x.y` UA — a Flutter-shell
// tell — off the wire for the verdict POST, the GCD rescue, and the
// push-image fetch.
// ============================================================

class StampedClient {
  StampedClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  Map<String, String> _withStamp(Map<String, String>? headers) {
    return <String, String>{
      ...?headers,
      'User-Agent': AgentStamp.value,
    };
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _inner.post(url, headers: _withStamp(headers), body: body);
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return _inner.get(url, headers: _withStamp(headers));
  }

  /// Convenience for binary fetches (push images).
  Future<Uint8List?> fetchBytes(Uri url, {Duration? timeout}) async {
    try {
      Future<http.Response> call = get(url);
      if (timeout != null) call = call.timeout(timeout);
      final http.Response res = await call;
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  void dispose() => _inner.close();
}

/// Shared instance, safe to use after `AgentStamp.warmUp()`.
final StampedClient stampedClient = StampedClient();
