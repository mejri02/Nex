import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../player/player_page.dart';
import '../services/movies_service.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  late final MoviesService _service;
  final _search = TextEditingController();
  List<MovieItem> _movies = [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _service = MoviesService();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _service.close();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final movies = await _service.fetchMovies();
      if (!mounted || request != _request) return;
      setState(() {
        _movies = movies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<MovieItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _movies;
    return _movies.where((m) =>
      m.title.toLowerCase().contains(q) ||
      m.genres.any((g) => g.toLowerCase().contains(q)) ||
      m.releaseDate.toLowerCase().contains(q)
    ).toList(growable: false);
  }

  Future<void> _openMovie(MovieItem movie) async {
    final c = AppScope.read(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final details = await _service.fetchMovieDetails(movie);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (details == null || details.servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.t('movieServersUnavailable'))),
      );
      return;
    }
    final selected = await showModalBottomSheet<MovieServer>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final server in details.servers)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: Text(server.name),
                  subtitle: Text(server.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(sheetContext, server),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final channel = Channel(
      id: 'movie-${movie.provider}-${movie.id}',
      name: movie.title,
      group: 'Movies',
      logo: movie.poster,
      sources: [
        StreamSource(name: selected.name, url: selected.url),
        for (final server in details.servers)
          if (server.url != selected.url)
            StreamSource(name: server.name, url: server.url),
      ],
    );
    // The chosen server starts first; the remaining servers stay available
    // for the player's normal failover controls and history handling.
    openPlayer(context, [channel], 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final movies = _filtered;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.t('movies'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: c.t('refreshNow'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: c.t('searchMovies'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading && _movies.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _movies.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 44),
                              const SizedBox(height: 12),
                              Text(c.t('moviesLoadFailed'), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 16),
                              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(c.t('retry'))),
                            ],
                          ),
                        ),
                      )
                    : movies.isEmpty
                        ? Center(child: Text(c.t('noMovies'), style: TextStyle(color: cs.onSurfaceVariant)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: MediaQuery.of(context).size.width > 700 ? 190 : 155,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                              itemCount: movies.length,
                              itemBuilder: (context, index) => _MovieCard(
                                movie: movies[index],
                                onTap: () => _openMovie(movies[index]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.movie, required this.onTap});

  final MovieItem movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.poster.isNotEmpty)
                    Image.network(
                      movie.poster,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _PosterFallback(),
                    )
                  else
                    const _PosterFallback(),
                  if (movie.rating != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(movie.rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15)),
                  if (movie.releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(movie.releaseDate, maxLines: 1, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.movie_outlined, size: 42)),
  );
}
