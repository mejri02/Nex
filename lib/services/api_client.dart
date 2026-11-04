import 'dart:convert';
import 'package:http/http.dart' as http;

/// Small HTTP client for endpoints the user is authorized to access.
/// It deliberately does not bypass login, subscription, or server rules.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<dynamic> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Request failed (${response.statusCode}) for ${uri.host}${uri.path}',
      );
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('The server did not return valid JSON.');
    }
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
