import 'dart:convert';

import '../config/frenzy_gate_config.dart';
import '../core/gate_models.dart';
import 'frenzy_safe.dart';
import 'plume_agent.dart';
import 'wing_attribution.dart';

/// POSTs the attribution payload to the config endpoint and interprets
/// the reply as a routing decision.
class GateExchange {
  GateExchange(this._agent, this._safe);

  final PlumeAgent _agent;
  final FrenzySafe _safe;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!FrenzyGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      ffrTrace(() => '[FFR.EXCH] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(FrenzyGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      ffrTrace(
        () => '[FFR.EXCH] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _safe.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      ffrTrace(() => '[FFR.EXCH] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
