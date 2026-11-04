import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../player/player_page.dart';
import 'widgets.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final favs = c.favorites;
    final wide = MediaQuery.of(context).size.width;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.18), Theme.of(context).colorScheme.surface.withValues(alpha: 0.78)],
                ),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.t('favorites'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        '${favs.length} · ${c.t('items')}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => c.setGrid(!c.gridView),
                  icon: Icon(c.gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                ),
              ],
                ),
              ),
            ),
          ),
          Expanded(
            child: favs.isEmpty
                ? EmptyState(icon: Icons.star_border_rounded, title: c.t('noFavs'), subtitle: c.t('noFavsSub'))
                : c.gridView
                    ? GridView.builder(
                            cacheExtent: 800,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: wide > 700 ? 150 : 120,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: favs.length,
                        itemBuilder: (_, i) => ChannelCard(
                          channel: favs[i],
                          onTap: () => openPlayer(context, favs, i),
                          onLong: () => showChannelActions(context, favs[i], onPlay: () => openPlayer(context, favs, i)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: favs.length,
                        itemBuilder: (_, i) => ChannelTile(
                          channel: favs[i],
                          onTap: () => openPlayer(context, favs, i),
                          onLong: () => showChannelActions(context, favs[i], onPlay: () => openPlayer(context, favs, i)),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
