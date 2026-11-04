import 'api_client.dart';
import 'api_config.dart';

/// Read-only Firebase Realtime Database REST access.
/// Requests are subject to the project's existing security rules.
/// No embedded Admin SDK credentials are used.
class KobaniDatabaseService {
  KobaniDatabaseService({ApiClient? client}) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> readManagedPlaylist() =>
      _read('sync/global/managedPlaylist');

  Future<dynamic> readChannelGroups() =>
      _read('sync/global/channelGroups');

  Future<dynamic> _read(String path) {
    final uri = Uri.parse(
      '${ApiConfig.firebaseDatabase}/$path.json',
    );
    return _api.getJson(uri);
  }

  void close() => _api.close();
}
