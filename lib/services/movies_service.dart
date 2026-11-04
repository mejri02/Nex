import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Normalized movie item used by the Movies hub, independent of its provider.
class MovieItem {
  const MovieItem({
    required this.id,
    required this.title,
    required this.provider,
    this.poster = '',
    this.backdrop = '',
    this.rating,
    this.releaseDate = '',
    this.genres = const [],
  });

  final String id;
  final String title;
  final String provider;
  final String poster;
  final String backdrop;
  final double? rating;
  final String releaseDate;
  final List<String> genres;
}

/// A playable server reported by a provider API.
class MovieServer {
  const MovieServer({required this.name, required this.url});

  final String name;
  final String url;
}

/// Provider-neutral response for a movie details request.
class MovieDetails {
  const MovieDetails({required this.movie, this.servers = const []});

  final MovieItem movie;
  final List<MovieServer> servers;
}

/// Reads movie metadata from the public KURDFILM API.
/// Other providers are intentionally added only after their request contracts
/// (including any required POST body or authentication) have been verified.
class MoviesService {
  MoviesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<MovieItem>> fetchKurdfilmMovies({int page = 1, int perPage = 100}) async {
    final uri = Uri.parse('${ApiConfig.kurdfilmBase}${ApiConfig.kurdfilmTitles}')
        .replace(queryParameters: {
      'kind': 'movie',
      'sort': 'newest',
      'per_page': '$perPage',
      'page': '$page',
    });
    final json = await _getJson(uri);
    final rows = _extractList(json);
    return rows
        .map((row) => _movieFromMap(row, provider: 'KURDFILM'))
        .where((movie) => movie != null)
        .cast<MovieItem>()
        .toList(growable: false);
  }

  Future<MovieDetails?> fetchKurdfilmDetails(MovieItem movie) async {
    final id = Uri.encodeComponent(movie.id);
    // The API has exposed both routes in different deployments. Try the
    // movie-specific route first, then the generic title route.
    for (final path in ['/movies/$id', '/titles/$id']) {
      try {
        final json = await _getJson(Uri.parse('${ApiConfig.kurdfilmBase}$path'));
        final map = _extractMap(json);
        if (map == null) continue;
        final updated = _movieFromMap(map, provider: movie.provider) ?? movie;
        return MovieDetails(movie: updated, servers: _extractServers(map));
      } catch (_) {
        // Continue to the documented fallback route.
      }
    }
    return null;
  }

  Future<dynamic> _getJson(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MoviesApiException('HTTP ${response.statusCode} from ${uri.host}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MoviesApiException('The provider returned invalid JSON.');
    }
  }

  static List<Map<String, dynamic>> _extractList(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in ['data', 'items', 'results', 'titles', 'movies']) {
        final nested = map[key];
        if (nested is List) return _extractList(nested);
        if (nested is Map) {
          final found = _extractList(nested);
          if (found.isNotEmpty) return found;
        }
      }
    }
    return const [];
  }

  static Map<String, dynamic>? _extractMap(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    for (final key in ['data', 'item', 'title', 'movie']) {
      if (map[key] is Map) return Map<String, dynamic>.from(map[key] as Map);
    }
    return map;
  }

  static MovieItem? _movieFromMap(
    Map<String, dynamic> map, {
    required String provider,
  }) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
      }
      return '';
    }

    final id = read(['id', 'movieId', 'movie_id', 'slug']);
    final title = read(['title', 'name', 'originalTitle']);
    if (id.isEmpty || title.isEmpty) return null;

    final rawRating = map['rating'] ?? map['vote_average'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse('${rawRating ?? ''}');
    final rawGenres = map['genres'] ?? map['genre'];
    final genres = rawGenres is List
        ? rawGenres.map((e) => e is Map ? '${e['name'] ?? ''}' : '$e')
            .where((e) => e.trim().isNotEmpty).toList(growable: false)
        : rawGenres is String && rawGenres.trim().isNotEmpty
            ? rawGenres.split(',').map((e) => e.trim()).toList(growable: false)
            : const <String>[];

    return MovieItem(
      id: id,
      title: title,
      provider: provider,
      poster: read(['image', 'poster', 'poster_url', 'thumbnail']),
      backdrop: read(['backdrop', 'backdrop_url', 'cover']),
      rating: rating,
      releaseDate: read(['releaseDate', 'release_date', 'year']),
      genres: genres,
    );
  }

  static List<MovieServer> _extractServers(Map<String, dynamic> map) {
    final raw = map['servers'] ?? map['movieServers'] ?? map['sources'];
    if (raw is! List) return const [];
    final result = <MovieServer>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final server = Map<String, dynamic>.from(item);
      final url = '${server['url'] ?? server['link'] ?? server['src'] ?? ''}'.trim();
      if (url.isEmpty) continue;
      final name = '${server['name'] ?? server['title'] ?? 'SERVER ${result.length + 1}'}'.trim();
      result.add(MovieServer(name: name, url: url));
    }
    return result;
  }

  void close() => _client.close();
}

class MoviesApiException implements Exception {
  const MoviesApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
