import 'dart:convert';

import '../core/models.dart';

final RegExp _attr = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

/// Parses an M3U / M3U8 playlist into channels.
List<Channel> parseM3u(String text, {String idPrefix = 'm3u'}) {
  final out = <Channel>[];
  String? name;
  var group = '', logo = '', ua = '', ref = '';
  var n = 0;

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      final attrs = <String, String>{
        for (final m in _attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!,
      };
      final q = line.lastIndexOf('"');
      final comma = line.indexOf(',', q < 0 ? 0 : q);
      var title = comma >= 0 ? line.substring(comma + 1).trim() : '';
      if (title.isEmpty) title = attrs['tvg-name'] ?? '';
      name = title;
      group = (attrs['group-title'] ?? '').trim();
      logo = (attrs['tvg-logo'] ?? '').trim();
      ua = '';
      ref = '';
    } else if (line.startsWith('#EXTGRP:')) {
      if (group.isEmpty) group = line.substring(8).trim();
    } else if (line.startsWith('#EXTVLCOPT:')) {
      final opt = line.substring(11);
      final eq = opt.indexOf('=');
      if (eq > 0) {
        final k = opt.substring(0, eq).toLowerCase();
        final v = opt.substring(eq + 1).trim();
        if (k == 'http-user-agent') ua = v;
        if (k == 'http-referrer' || k == 'http-referer') ref = v;
      }
    } else if (line.startsWith('#')) {
      continue;
    } else if (name != null) {
      if (name.isNotEmpty && RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(line)) {
        out.add(Channel(
          id: '$idPrefix-${n++}',
          name: name,
          group: group,
          logo: logo,
          sources: [StreamSource(name: 'SERVER 1', url: line, userAgent: ua, referer: ref)],
        ));
      }
      name = null;
    }
  }
  return out;
}
