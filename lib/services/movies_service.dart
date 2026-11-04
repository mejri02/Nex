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

class MovieServer {
  const MovieServer({required this.name, required this.url});
  final String name;
  final String url;
}

class MovieDetails {
  const MovieDetails({required this.movie, this.servers = const []});
  final MovieItem movie;
  final List<MovieServer> servers;
}

/// Aggregates public movie metadata. Provider playback links are only exposed
/// when they are actually returned by the provider's detail response.
class MoviesService {
  MoviesService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<MovieItem>> fetchMovies() async {
    final results = await Future.wait<List<MovieItem>>([
      _tryLoad(fetchKurdfilmMovies),
      _tryLoad(fetchMoviesKurdishMovies),
    ]);
    final unique = <String, MovieItem>{};
    for (final list in results) {
      for (final movie in list) {
        unique['${movie.provider}|${movie.id}'] = movie;
      }
    }
    return unique.values.toList(growable: false);
  }

  Future<List<MovieItem>> _tryLoad(Future<List<MovieItem>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  Future<List<MovieItem>> fetchKurdfilmMovies({int page = 1, int perPage = 100}) async {
    final uri = Uri.parse('${ApiConfig.kurdfilmBase}${ApiConfig.kurdfilmTitles}')
        .replace(queryParameters: {
      'kind': 'movie',
      'sort': 'newest',
      'per_page': '$perPage',
      'page': '$page',
    });
    final json = await _getJson(uri);
    return _extractList(json)
        .map((row) => _movieFromMap(row, provider: 'KURDFILM'))
        .whereType<MovieItem>()
        .toList(growable: false);
  }

  Future<List<MovieItem>> fetchMoviesKurdishMovies({int maxResults = 24}) async {
    final uri = Uri.https('www.movieskurdish.com', '/feeds/posts/default', {
      'alt': 'json',
      'max-results': '$maxResults',
      'start-index': '1',
    });
    final json = await _getJson(uri);
    final feed = json is Map ? json['feed'] : null;
    final entries = feed is Map ? feed['entry'] : null;
    if (entries is! List) return const [];
    final movies = <MovieItem>[];
    for (final item in entries) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final idTag = _text(entry['id']);
      final idMatch = RegExp(r'post-(\d+)').firstMatch(idTag);
      final id = idMatch?.group(1) ?? '';
      final title = _text(entry['title']);
      if (id.isEmpty || title.isEmpty) continue;
      final media = entry['media$thumbnail'];
      final poster = media is Map ? '${media['url'] ?? ''}' : _firstImage(_text(entry['content']));
      final published = _text(entry['published']);
      movies.add(MovieItem(
        id: id,
        title: title,
        provider: 'MOVIESKURDISH',
        poster: poster,
        releaseDate: published.isEmpty ? '' : published.split('T').first,
      ));
    }
    return movies;
  }

  Future<MovieDetails?> fetchMovieDetails(MovieItem movie) {
    switch (movie.provider) {
      case 'KURDFILM':
        return fetchKurdfilmDetails(movie);
      case 'MOVIESKURDISH':
        return fetchMoviesKurdishDetails(movie);
      default:
        return Future.value(null);
    }
  }

  Future<MovieDetails?> fetchKurdfilmDetails(MovieItem movie) async {
    final id = Uri.encodeComponent(movie.id);
    for (final path in ['/movies/$id', '/titles/$id']) {
      try {
        final json = await _getJson(Uri.parse('${ApiConfig.kurdfilmBase}$path'));
        final map = _extractMap(json);
        if (map == null) continue;
        final updated = _movieFromMap(map, provider: movie.provider) ?? movie;
        return MovieDetails(movie: updated, servers: _extractServers(map));
      } catch (_) {
        // Try the documented fallback route.
      }
    }
    return null;
  }

  Future<MovieDetails?> fetchMoviesKurdishDetails(MovieItem movie) async {
    final uri = Uri.https('www.movieskurdish.com', '/feeds/posts/default/${Uri.encodeComponent(movie.id)}', {'alt': 'json'});
    try {
      final json = await _getJson(uri);
      final feed = json is Map ? json['entry'] ?? json['feed'] : null;
      final entry = feed is Map && feed['entry'] is Map
          ? Map<String, dynamic>.from(feed['entry'] as Map)
          : feed is Map
              ? Map<String, dynamic>.from(feed)
              : null;
      if (entry == null) return MovieDetails(movie: movie);
      final html = _text(entry['content']);
      final match = RegExp(
        r'<textarea[^>]*id="video-data"[^>]*>([\s\S]*?)</textarea>',
        caseSensitive: false,
      ).firstMatch(html);
      if (match == null) return MovieDetails(movie: movie);
      final raw = _decodeHtml(match.group(1) ?? '');
      dynamic data;
      try {
        data = jsonDecode(raw);
      } catch (_) {
        return MovieDetails(movie: movie);
      }
      return MovieDetails(movie: movie, servers: _deepServers(data));
    } catch (_) {
      return null;
    }
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

  static String _text(dynamic value) {
    if (value is Map) return '${value[r'$t'] ?? ''}'.trim();
    return '${value ?? ''}'.trim();
  }

  static String _firstImage(String html) {
    final match = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)', caseSensitive: false).firstMatch(html);
    return match?.group(1) ?? '';
  }

  static String _decodeHtml(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();

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

  static MovieItem? _movieFromMap(Map<String, dynamic> map, {required String provider}) {
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
    final rating = rawRating is num ? rawRating.toDouble() : double.tryParse('${rawRating ?? ''}');
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

  static List<MovieServer> _deepServers(dynamic value) {
    final result = <MovieServer>[];
    final seen = <String>{};
    void visit(dynamic node) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        final url = '${map['url'] ?? map['link'] ?? map['src'] ?? ''}'.trim();
        if (url.startsWith('http://') || url.startsWith('https://')) {
          if (seen.add(url)) {
            result.add(MovieServer(
              name: '${map['name'] ?? map['title'] ?? 'SERVER ${result.length + 1}'}',
              url: url,
            ));
          }
        }
        for (final child in map.values) {
          if (child is Map || child is List) visit(child);
        }
      } else if (node is List) {
        for (final child in node) {
          if (child is Map || child is List) visit(child);
        }
      }
    }
    visit(value);
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
