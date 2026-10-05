import 'dart:convert';

import '../config/gate_settings.dart';
import '../model/route_outcome.dart';
import '../store/vault_box.dart';
import 'stamped_client.dart';

// ============================================================
// GATE QUERY — POST the body, parse + cache the reply
// ============================================================
// The backend is the only authority on routing. On a granted reply
// the URL and its expiry are cached so a returning launch can skip
// the network while the URL is fresh. Any failure (HTTP error,
// timeout, bad JSON) returns a denied reply; the warden turns that
// into a native landing, or an offline landing when the net is down.
// ============================================================

class GateQuery {
  GateQuery(this._vault);

  final VaultBox _vault;

  Future<GateReply> ask(Map<String, dynamic> body) async {
    final String endpoint = GateSettings.verdictUrl;
    if (endpoint.isEmpty) return GateReply.denied('endpoint_unset');

    try {
      final dynamic res = await stampedClient
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(GateSettings.verdictTimeout);

      if (res.statusCode != 200) {
        return GateReply.denied('http_${res.statusCode}');
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map) return GateReply.denied('malformed');

      final GateReply reply =
          GateReply.parse(Map<String, dynamic>.from(decoded));
      if (reply.pointsSomewhere) {
        await _vault.cacheDestination(reply.url!, reply.expiresUnix);
      }
      return reply;
    } catch (e) {
      return GateReply.denied('net:$e');
    }
  }
}
