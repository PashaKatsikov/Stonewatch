import 'dart:convert';

import '../config/settings.dart';
import '../model/outcome.dart';
import '../store/prefs_store.dart';
import 'api_client.dart';

// ============================================================
// GATE QUERY — POST the body, parse + cache the reply
// ============================================================
// The backend is the only authority on routing. On a granted reply
// the URL and its expiry are cached so a returning launch can skip
// the network while the URL is fresh. Any failure (HTTP error,
// timeout, bad JSON) returns a denied reply; the warden turns that
// into a native landing, or an offline landing when the net is down.
// ============================================================

class ConfigQuery {
  ConfigQuery(this._vault);

  final PrefsStore _vault;

  Future<ServerReply> ask(Map<String, dynamic> body) async {
    final String endpoint = AppSettings.verdictUrl;
    if (endpoint.isEmpty) return ServerReply.denied('endpoint_unset');

    try {
      final dynamic res = await apiClient
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(AppSettings.verdictTimeout);

      if (res.statusCode != 200) {
        return ServerReply.denied('http_${res.statusCode}');
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map) return ServerReply.denied('malformed');

      final ServerReply reply =
          ServerReply.parse(Map<String, dynamic>.from(decoded));
      if (reply.pointsSomewhere) {
        await _vault.cacheDestination(reply.url!, reply.expiresUnix);
      }
      return reply;
    } catch (e) {
      return ServerReply.denied('net:$e');
    }
  }
}
