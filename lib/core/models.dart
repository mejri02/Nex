/// A single playable URL of a channel (a channel can have several servers).
class StreamSource {
  const StreamSource({
    required this.name,
    required this.url,
    this.userAgent = '',
    this.referer = '',
    this.drm = false,
  });

  final String name, url, userAgent, referer;
  final bool drm;

  Map<String, dynamic> toJson() => {
        'n': name,
        'u': url,
        if (userAgent.isNotEmpty) 'ua': userAgent,
        if (referer.isNotEmpty) 'r': referer,
        if (drm) 'd': 1,
      };

  factory StreamSource.fromJson(Map<String, dynamic> j) => StreamSource(
        name: '${j['n'] ?? ''}',
        url: '${j['u'] ?? ''}',
        userAgent: '${j['ua'] ?? ''}',
        referer: '${j['r'] ?? ''}',
        drm: j['d'] == 1,
      );
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.group,
    required this.logo,
    required this.sources,
  });

  final String id, name, group, logo;
  final List<StreamSource> sources;

  /// Stable identity used by favorites / history.
  String get key => '${name.toLowerCase()}|${sources.isEmpty ? '' : sources.first.url}';

  Map<String, dynamic> toJson() => {
        'i': id,
        'n': name,
        'g': group,
        'l': logo,
        's': sources.map((e) => e.toJson()).toList(),
      };

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: '${j['i'] ?? ''}',
        name: '${j['n'] ?? ''}',
        group: '${j['g'] ?? ''}',
        logo: '${j['l'] ?? ''}',
        sources: [
          for (final s in (j['s'] as List? ?? const []))
            if (s is Map) StreamSource.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
}

/// A place channels come from: the built-in API, an M3U link or an Xtream account.
class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.name,
    required this.type,
    this.url = '',
    this.user = '',
    this.pass = '',
    this.format = 'm3u8',
  });

  static const builtinId = 'builtin';

  final String id, name, type, url, user, pass, format;
  bool get builtin => type == 'builtin';

  SourceConfig copyWith({String? name, String? type, String? url, String? user, String? pass, String? format}) =>
      SourceConfig(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        url: url ?? this.url,
        user: user ?? this.user,
        pass: pass ?? this.pass,
        format: format ?? this.format,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'user': user,
        'pass': pass,
        'format': format,
      };

  factory SourceConfig.fromJson(Map<String, dynamic> j) => SourceConfig(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        type: '${j['type'] ?? 'm3u'}',
        url: '${j['url'] ?? ''}',
        user: '${j['user'] ?? ''}',
        pass: '${j['pass'] ?? ''}',
        format: '${j['format'] ?? 'm3u8'}',
      );
}

class GroupInfo {
  const GroupInfo(this.name, this.count, this.locked);
  final String name;
  final int count;
  final bool locked;
}

/// Subscription details of an Xtream account.
class AccountInfo {
  const AccountInfo({this.status = '', this.expiry, this.maxConnections = '', this.activeConnections = ''});
  final String status, maxConnections, activeConnections;
  final DateTime? expiry;
}
