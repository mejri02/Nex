import 'dart:convert';
import 'package:http/http.dart' as http;

const endpoints = <String, String>{
  'Beenar movies': 'https://beenar.net/api/client/movie',
  'Beenar shows': 'https://beenar.net/api/client/title-show/',
  'KurdFilm movies': 'https://app.kurdfilm.krd/api/movies/',
  'KurdFilm titles': 'https://app.kurdfilm.krd/api/titles',
};

Future<void> main() async {
  final client = http.Client();
  try {
    for (final entry in endpoints.entries) {
      final uri = Uri.parse(entry.value);
      stdoutLine('Checking ${entry.key} ...');
      try {
        final response = await client.get(uri).timeout(
          const Duration(seconds: 15),
        );
        final contentType = response.headers['content-type'] ?? 'unknown';
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final looksJson = _isJson(contentType, body);
        stdoutLine('  HTTP ${response.statusCode}');
        stdoutLine('  Content-Type: $contentType');
        stdoutLine('  Body bytes: ${response.bodyBytes.length}');
        stdoutLine('  JSON-like: $looksJson');
        if (response.statusCode == 401 || response.statusCode == 403) {
          stdoutLine('  Result: endpoint requires authorization or access.');
        } else if (response.statusCode >= 200 && response.statusCode < 300) {
          stdoutLine('  Result: server responded; inspect schema before mapping.');
        } else {
          stdoutLine('  Result: server returned an error; this does not prove the API is permanently unavailable.');
        }
      } catch (e) {
        stdoutLine('  Connection error: $e');
      }
      stdoutLine('');
    }
  } finally {
    client.close();
  }
}

bool _isJson(String contentType, String body) {
  if (contentType.toLowerCase().contains('json')) return true;
  final trimmed = body.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

void stdoutLine(String value) => print(value);
