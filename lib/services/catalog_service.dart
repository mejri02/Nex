import 'api_client.dart';
import 'api_config.dart';

/// Catalog endpoints identified in the APK.
/// These methods return raw decoded JSON until the exact response schemas
/// are confirmed against authorized live responses.
class CatalogService {
  CatalogService({ApiClient? client}) : _api = client ?? ApiClient();
  final ApiClient _api;

  Future<dynamic> beenarMovies() => _api.getJson(
    Uri.parse('${ApiConfig.beenarBase}${ApiConfig.beenarMovies}'),
  );

  Future<dynamic> beenarShows() => _api.getJson(
    Uri.parse('${ApiConfig.beenarBase}${ApiConfig.beenarShows}'),
  );

  Future<dynamic> kurdfilmMovies() => _api.getJson(
    Uri.parse('${ApiConfig.kurdfilmBase}${ApiConfig.kurdfilmMovies}'),
  );

  Future<dynamic> kurdfilmTitles() => _api.getJson(
    Uri.parse('${ApiConfig.kurdfilmBase}${ApiConfig.kurdfilmTitles}'),
  );

  void close() => _api.close();
}
