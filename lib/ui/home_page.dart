import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../player/player_page.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenGroup, required this.onOpenChannels});
  final void Function(String group) onOpenGroup;
  final VoidCallback onOpenChannels;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final all = c.visible;
    final groups = c.groups;
    final resume = c.history.isNotEmpty ? c.history.first : (all.isNotEmpty ? all.first : null);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => c.loadChannels(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(onSearch: onOpenChannels)),
            if (c.loading && all.isEmpty)
              const SliverToBoxAdapter(child: _Skeleton())
            else if (c.error != null && all.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 360,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: c.t('loadFail'),
                    subtitle: c.error,
                    actionLabel: c.t('retry'),
                    onAction: () => c.loadChannels(force: true),
                  ),
                ),
              )
            else ...[
              if (c.loading)
                SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2, color: cs.primary)),
              if (resume != null)
                SliverToBoxAdapter(
                  child: _Hero(
                    channel: resume,
                    isResume: c.history.isNotEmpty,
                    onPlay: () => openPlayer(context, c.history.isNotEmpty ? c.history : all, 0),
                  ),
                ),
              if (c.history.length > 1) ...[
                SliverToBoxAdapter(child: SectionTitle(c.t('recent'))),
                SliverToBoxAdapter(child: _Row(channels: c.history.skip(1).toList())),
              ],
              if (c.favorites.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionTitle(c.t('favorites'))),
                SliverToBoxAdapter(child: _Row(channels: c.favorites)),
              ],
              if (groups.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionTitle(c.t('categories'), action: c.t('seeAll'), onAction: onOpenChannels)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: groups.length > 24 ? 24 : groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => GroupTile(
                        group: groups[i],
                        width: 148,
                        onTap: () => onOpenGroup(groups[i].name),
                      ),
                    ),
                  ),
                ),
                // A few ready-made rows from the biggest categories.
                for (final g in groups.where((g) => !c.isLocked(g.name) && g.name.isNotEmpty).take(4)) ...[
                  SliverToBoxAdapter(
                    child: SectionTitle(g.name, action: c.t('seeAll'), onAction: () => onOpenGroup(g.name)),
                  ),
                  SliverToBoxAdapter(child: _Row(channels: c.channelsOfGroup(g.name, limit: 14), contextList: c.channelsOfGroup(g.name))),
                ],
              ],
              if (all.isEmpty && !c.loading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: EmptyState(
                      icon: Icons.live_tv_rounded,
                      title: c.t('welcomeTitle'),
                      subtitle: c.t('welcomeSub'),
                    ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.55)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.play_arrow_rounded, color: cs.onPrimary, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('KOBANI ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  Text('4K', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.primary)),
                ]),
                Text(
                  c.activeSource.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded)),
          IconButton(
            onPressed: c.loading ? null : () => c.loadChannels(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.channel, required this.isResume, required this.onPlay});
  final Channel channel;
  final bool isResume;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final pal = paletteFor(channel.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Tappable(
        onTap: onPlay,
        radius: 26,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pal[0].withValues(alpha: 0.85), cs.surface],
            ),
          ),
          child: Row(
            children: [
              Logo(url: channel.logo, size: 84, radius: 20, name: channel.name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        isResume ? c.t('continueWatching') : c.t('featured'),
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (channel.group.isNotEmpty)
                      Text(channel.group, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: cs.onPrimary, size: 34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.channels, this.contextList});
  final List<Channel> channels;

  /// Playlist handed to the player (so zapping stays inside the same list).
  final List<Channel>? contextList;

  @override
  Widget build(BuildContext context) {
    final list = contextList ?? channels;
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final ch = channels[i];
          void play() {
            final idx = list.indexWhere((e) => e.key == ch.key);
            openPlayer(context, list, idx < 0 ? 0 : idx);
          }

          return ChannelCard(
            channel: ch,
            width: 112,
            onTap: play,
            onLong: () => showChannelActions(context, ch, onPlay: play),
          );
        },
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget box(double w, double h, [double r = 18]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(r)),
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(double.infinity, 120, 26),
          const SizedBox(height: 24),
          box(140, 18, 8),
          const SizedBox(height: 12),
          Row(children: [for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(right: 12), child: box(78, 120))]),
          const SizedBox(height: 18),
          const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))),
        ],
      ),
    );
  }
}
