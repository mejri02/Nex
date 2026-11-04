import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../player/player_page.dart';
import 'widgets.dart';

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  final _search = TextEditingController();
  bool _synced = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickGroup(AppController c, GroupInfo g) async {
    if (c.isLocked(g.name)) {
      final ok = await askPin(context, g.name);
      if (!ok) return;
    }
    c.setGroupFilter(g.name);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!_synced) {
      _search.text = c.query;
      _synced = true;
    }
    final groups = c.groups;
    final list = c.filtered();
    final wide = MediaQuery.of(context).size.width;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: c.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: c.t('search'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                c.setQuery('');
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: c.gridView ? c.t('list') : c.t('grid'),
                  onPressed: () => c.setGrid(!c.gridView),
                  icon: Icon(c.gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(cs, c.t('all'), '${c.totalCount}', c.groupFilter.isEmpty, () => c.setGroupFilter('')),
                for (final g in groups)
                  _chip(
                    cs,
                    g.name.isEmpty ? c.t('uncategorized') : g.name,
                    '${g.count}',
                    c.groupFilter == g.name && c.groupFilter.isNotEmpty,
                    () => _pickGroup(c, g),
                    locked: c.isLocked(g.name),
                  ),
              ],
            ),
          ),
          Expanded(
            child: c.loading && list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: c.error != null ? Icons.cloud_off_rounded : Icons.search_off_rounded,
                        title: c.error != null ? c.t('loadFail') : c.t('noResults'),
                        subtitle: c.error ?? c.t('noResultsSub'),
                        actionLabel: c.error != null ? c.t('retry') : null,
                        onAction: () => c.loadChannels(force: true),
                      )
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
                            itemCount: list.length,
                            itemBuilder: (_, i) => _card(context, list, i),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24, top: 4),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final ch = list[i];
                              return ChannelTile(
                                channel: ch,
                                onTap: () => openPlayer(context, list, i),
                                onLong: () => showChannelActions(context, ch, onPlay: () => openPlayer(context, list, i)),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, List<Channel> list, int i) {
    final ch = list[i];
    return ChannelCard(
      channel: ch,
      onTap: () => openPlayer(context, list, i),
      onLong: () => showChannelActions(context, ch, onPlay: () => openPlayer(context, list, i)),
    );
  }

  Widget _chip(ColorScheme cs, String label, String count, bool selected, VoidCallback onTap, {bool locked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: locked ? const Icon(Icons.lock_rounded, size: 16) : null,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Text(count, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        selectedColor: cs.primary.withValues(alpha: 0.25),
        side: BorderSide(color: selected ? cs.primary : Colors.transparent),
      ),
    );
  }
}
