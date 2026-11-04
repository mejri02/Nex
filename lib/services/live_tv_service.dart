import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';

/// Loads the channels of the built-in API (same endpoint as the original app).
/// Filtering by words is now done by the user from Settings, not hard-coded.
class LiveTvService {
  LiveTvService(this._client);
  final http.Client _client;

  static const base = 'https://api.optictv.cloud/api/collections';

  static StreamSource? _src(Map j, String suffix, String fallbackName) {
    final url = '${j[suffix.isEmpty ? 'url' : 'url$suffix'] ?? ''}'.trim();
    if (url.isEmpty) return null;
    final named = '${j[suffix.isEmpty ? 'urlName' : 'url${suffix}Name'] ?? ''}'.trim();
    final p = suffix.isEmpty ? '' : 'url$suffix';
    String f(String k) => '${j[p.isEmpty ? k : '$p${k[0].toUpperCase()}${k.substring(1)}'] ?? ''}';
    return StreamSource(
      name: named.isEmpty ? fallbackName : named,
      url: url,
      userAgent: f('userAgent'),
      referer: f('referer'),
      drm: f('drmScheme').isNotEmpty || f('drmLicense').isNotEmpty,
    );
  }

  Future<List<Channel>> fetchChannels() async {
    final channels = <Channel>[];
    var page = 1, pages = 1;
    do {
      final uri = Uri.parse('$base/managedPlaylist/records?perPage=500&page=$page');
      final response = await _client.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      pages = (body['totalPages'] as num?)?.toInt() ?? 1;
      for (final item in (body['items'] as List? ?? const [])) {
        if (item is! Map) continue;
        final type = '${item['type'] ?? 'live'}'.toLowerCase();
        if (type != 'live' && type != 'sport' && type != 'sports') continue;
        final name = '${item['name'] ?? ''}'.trim();
        final sources = <StreamSource>[
          if (_src(item, '', 'SERVER 1') != null) _src(item, '', 'SERVER 1')!,
          if (_src(item, '2', 'SERVER 2') != null) _src(item, '2', 'SERVER 2')!,
          if (_src(item, '3', 'SERVER 3') != null) _src(item, '3', 'SERVER 3')!,
        ];
        if (name.isEmpty || sources.isEmpty) continue;
        channels.add(Channel(
          id: '${item['id'] ?? ''}',
          name: name,
          group: '${item['group'] ?? item['category'] ?? ''}'.trim(),
          logo: '${item['logo'] ?? item['icon_url'] ?? ''}',
          sources: sources,
        ));
      }
      page++;
    } while (page <= pages);
    channels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return channels;
  }
}
