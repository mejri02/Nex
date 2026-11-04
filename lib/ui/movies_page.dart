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
  List<MovieItem> _catalog = [];
  bool _loading = true;
  String? _error;
  String _kind = 'all';
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
      final items = await _service.fetchMovies();
      if (!mounted || request != _request) return;
      setState(() {
        _catalog = items;
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
    return _catalog.where((item) {
      if (_kind != 'all' && item.kind != _kind) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.genres.any((g) => g.toLowerCase().contains(q)) ||
          item.releaseDate.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  Future<void> _openTitle(MovieItem item) async {
    final app = AppScope.read(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    MovieDetails? details;
    try {
      details = await _service.fetchMovieDetails(item);
    } catch (_) {
      details = null;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (details == null) {
      _message(app.t('movieDetailsUnavailable'));
      return;
    }
    if (item.kind == 'series') {
      if (details.seasons.isEmpty) {
        _message(app.t('seriesDataUnavailable'));
        return;
      }
      final episode = await _pickEpisode(details.seasons);
      if (episode != null) await _playEpisode(item, details.seasons, episode);
      return;
    }
    if (details.servers.isEmpty) {
      _message(app.t('movieServersUnavailable'));
      return;
    }
    final server = await _pickServer(item.title, details.servers);
    if (server == null || !mounted) return;
    final channel = Channel(
      id: 'movie-${item.provider}-${item.id}',
      name: item.title,
      group: 'Movies',
      logo: item.poster,
      sources: _orderedServers(server, details.servers),
    );
    openPlayer(context, [channel], 0);
  }

  Future<MovieEpisode?> _pickEpisode(List<MovieSeason> seasons) {
    MovieSeason selected = seasons.first;
    return showModalBottomSheet<MovieEpisode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final cs = Theme.of(sheetContext).colorScheme;
          final strings = AppScope.of(sheetContext);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.t('seasonsEpisodes'),
                            style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text('${seasons.length}', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButtonFormField<int>(
                      value: selected.number,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: strings.t('season')),
                      items: [
                        for (final season in seasons)
                          DropdownMenuItem(value: season.number, child: Text(season.title)),
                      ],
                      onChanged: (number) {
                        final next = seasons.firstWhere((s) => s.number == number);
                        setSheetState(() => selected = next);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: selected.episodes.isEmpty
                        ? Center(child: Text(strings.t('episodeDataUnavailable'), style: TextStyle(color: cs.onSurfaceVariant)))
                        : ListView.separated(
                            itemCount: selected.episodes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final episode = selected.episodes[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.surfaceContainerHighest,
                                  child: Text('${episode.episodeNumber}'),
                                ),
                                title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  episode.servers.isEmpty ? strings.t('noVerifiedPlayback') : '${episode.servers.length} ${strings.t('servers')}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                ),
                                trailing: const Icon(Icons.play_circle_outline_rounded),
                                onTap: () => Navigator.pop(sheetContext, episode),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _playEpisode(MovieItem show, List<MovieSeason> seasons, MovieEpisode episode) async {
    if (episode.servers.isEmpty) {
      _message(AppScope.read(context).t('episodeServersUnavailable'));
      return;
    }
    final server = await _pickServer(episode.title, episode.servers);
    if (server == null || !mounted) return;

    final episodes = seasons.expand((s) => s.episodes).where((e) => e.servers.isNotEmpty).toList();
    final playlist = <Channel>[];
    var selectedIndex = 0;
    for (final e in episodes) {
      final isSelected = e.seasonNumber == episode.seasonNumber && e.episodeNumber == episode.episodeNumber;
      if (isSelected) selectedIndex = playlist.length;
      final sources = isSelected ? _orderedServers(server, e.servers) : e.servers.map((s) => StreamSource(name: s.name, url: s.url)).toList();
      playlist.add(Channel(
        id: 'episode-${show.provider}-${show.id}-${e.seasonNumber}-${e.episodeNumber}',
        name: '${show.title} · S${e.seasonNumber.toString().padLeft(2, '0')}E${e.episodeNumber.toString().padLeft(2, '0')} · ${e.title}',
        group: 'Series',
        logo: e.poster.isNotEmpty ? e.poster : show.poster,
        sources: sources,
      ));
    }
    if (playlist.isEmpty) {
      _message(AppScope.read(context).t('episodeServersUnavailable'));
      return;
    }
    openPlayer(context, playlist, selectedIndex);
  }

  Future<MovieServer?> _pickServer(String title, List<MovieServer> servers) {
    return showModalBottomSheet<MovieServer>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final server in servers)
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
  }

  List<StreamSource> _orderedServers(MovieServer selected, List<MovieServer> servers) => [
    StreamSource(name: selected.name, url: selected.url),
    for (final server in servers)
      if (server.url != selected.url) StreamSource(name: server.name, url: server.url),
  ];

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = _filtered;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text(app.t('movies'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                IconButton(
                  tooltip: app.t('refreshNow'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: app.t('searchMovies'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () { _search.clear(); setState(() {}); },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (final option in [('all', app.t('all')), ('movie', app.t('moviesOnly')), ('series', app.t('seriesOnly'))])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(option.$2),
                      selected: _kind == option.$1,
                      onSelected: (_) => setState(() => _kind = option.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _catalog.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _catalog.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 44),
                              const SizedBox(height: 12),
                              Text(app.t('moviesLoadFailed'), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 16),
                              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(app.t('retry'))),
                            ],
                          ),
                        ),
                      )
                    : items.isEmpty
                        ? Center(child: Text(app.t('noMovies'), style: TextStyle(color: cs.onSurfaceVariant)))
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
                              itemCount: items.length,
                              itemBuilder: (context, index) => _MovieCard(
                                item: items[index],
                                onTap: () => _openTitle(items[index]),
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
  const _MovieCard({required this.item, required this.onTap});
  final MovieItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppScope.of(context);
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
                  if (item.poster.isNotEmpty)
                    Image.network(item.poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _PosterFallback())
                  else
                    const _PosterFallback(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Text(
                          item.kind == 'series' ? strings.t('seriesTag') : strings.t('movieTag'),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  if (item.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(item.rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15)),
                  if (item.releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.releaseDate, maxLines: 1, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
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
