import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';

/// Minimal Xtream Codes client (live channels + account info).
/// Uses only the credentials the user typed for their own subscription.
class XtreamService {
  XtreamService(this._client);
  final http.Client _client;

  static String normalizeBase(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.contains('://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Uri _api(SourceConfig s, [String? action]) {
    final base = normalizeBase(s.url);
    return Uri.parse('$base/player_api.php').replace(queryParameters: {
      'username': s.user.trim(),
      'password': s.pass.trim(),
      if (action != null) 'action': action,
    });
  }

  Future<dynamic> _json(Uri uri) async {
    final r = await _client.get(uri).timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  }

  Future<List<Channel>> fetchLive(SourceConfig s) async {
    final cats = <String, String>{};
    final catJson = await _json(_api(s, 'get_live_categories'));
    if (catJson is List) {
      for (final c in catJson) {
        if (c is Map) cats['${c['category_id']}'] = '${c['category_name'] ?? ''}';
      }
    }
    final streams = await _json(_api(s, 'get_live_streams'));
    if (streams is! List) throw Exception('Invalid response (check username / password)');
    final base = normalizeBase(s.url);
    final ext = s.format == 'ts' ? 'ts' : 'm3u8';
    final out = <Channel>[];
    for (final it in streams) {
      if (it is! Map) continue;
      final id = '${it['stream_id'] ?? ''}';
      final name = '${it['name'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty) continue;
      out.add(Channel(
        id: '${s.id}-$id',
        name: name,
        group: cats['${it['category_id']}'] ?? '',
        logo: '${it['stream_icon'] ?? ''}',
        sources: [
          StreamSource(
            name: 'SERVER 1',
            url: '$base/live/${Uri.encodeComponent(s.user.trim())}/${Uri.encodeComponent(s.pass.trim())}/$id.$ext',
          ),
        ],
      ));
    }
    return out;
  }

  Future<AccountInfo> accountInfo(SourceConfig s) async {
    final j = await _json(_api(s));
    final u = (j is Map ? j['user_info'] : null);
    if (u is! Map) throw Exception('No account info');
    DateTime? exp;
    final e = int.tryParse('${u['exp_date'] ?? ''}');
    if (e != null && e > 0) exp = DateTime.fromMillisecondsSinceEpoch(e * 1000);
    return AccountInfo(
      status: '${u['status'] ?? ''}',
      expiry: exp,
      maxConnections: '${u['max_connections'] ?? ''}',
      activeConnections: '${u['active_cons'] ?? ''}',
    );
  }
}
