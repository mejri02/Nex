import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../player/player_page.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenGroup, required this.onOpenChannels, required this.onOpenFavorites});
  final void Function(String group) onOpenGroup;
  final VoidCallback onOpenChannels;
  final VoidCallback onOpenFavorites;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final all = c.visible;
    final groups = c.groups;
    final featured = c.history.isNotEmpty
        ? c.history.first
        : (c.favorites.isNotEmpty ? c.favorites.first : (all.isNotEmpty ? all.first : null));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => c.loadChannels(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cs.primary, cs.primary.withValues(alpha: 0.55)],
                        ),
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: cs.onPrimary, size: 31),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VYRA TV', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                          Text(c.activeSource.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: c.t('search'),
                      onPressed: onOpenChannels,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: c.t('refreshNow'),
                      onPressed: c.loading ? null : () => c.loadChannels(force: true),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: const Color(0xFF35D49A), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(c.t('live'), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 11)),
                    const Spacer(),
                    Text('${c.totalCount} ${c.t('items')}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ),
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
              if (featured != null)
                SliverToBoxAdapter(
                  child: _FeaturedCard(
                    channel: featured,
                    eyebrow: c.history.isNotEmpty ? c.t('continueWatching') : c.t('featured'),
                    onPlay: () {
                      final list = c.history.isNotEmpty ? c.history : all;
                      final index = list.indexWhere((e) => e.key == featured.key);
                      openPlayer(context, list, index < 0 ? 0 : index);
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Row(
                    children: [
                      Expanded(child: _QuickAction(icon: Icons.grid_view_rounded, title: c.t('channels'), value: '${c.totalCount}', onTap: onOpenChannels)),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickAction(icon: Icons.star_rounded, title: c.t('favorites'), value: '${c.favorites.length}', onTap: () {
                        // Favorites are also reachable from the persistent navigation bar.
                        Navigator.of(context).maybePop();
                      })),
                    ],
                  ),
                ),
              ),
              if (groups.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionTitle(c.t('categories'), action: c.t('seeAll'), onAction: onOpenChannels)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 126,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: groups.length > 20 ? 20 : groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => GroupTile(
                        group: groups[i],
                        width: 154,
                        onTap: () => onOpenGroup(groups[i].name),
                      ),
                    ),
                  ),
                ),
                for (final g in groups.where((g) => !c.isLocked(g.name) && g.name.isNotEmpty).take(4)) ...[
                  SliverToBoxAdapter(
                    child: SectionTitle(g.name, action: c.t('seeAll'), onAction: () => onOpenGroup(g.name)),
                  ),
                  SliverToBoxAdapter(
                    child: _ChannelRail(channels: c.channelsOfGroup(g.name, limit: 14), allChannels: c.channelsOfGroup(g.name)),
                  ),
                ],
              ],
              if (c.history.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionTitle(c.t('recent'))),
                SliverToBoxAdapter(child: _ChannelRail(channels: c.history, allChannels: c.history)),
              ],
              if (all.isEmpty && !c.loading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: EmptyState(icon: Icons.live_tv_rounded, title: c.t('welcomeTitle'), subtitle: c.t('welcomeSub')),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 34)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.channel, required this.eyebrow, required this.onPlay});
  final Channel channel;
  final String eyebrow;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = paletteFor(channel.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Tappable(
        onTap: onPlay,
        radius: 26,
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors[0], cs.surface, cs.surface],
              stops: const [0, 0.72, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 12))],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(30)),
                      child: Text(eyebrow, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 13),
                    Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.1)),
                    if (channel.group.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(channel.group, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
                    ],
                    const SizedBox(height: 15),
                    Row(children: [
                      Icon(Icons.play_circle_fill_rounded, color: cs.primary, size: 27),
                      const SizedBox(width: 7),
                      Text('PLAY', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)),
                child: Logo(url: channel.logo, size: 86, radius: 18, name: channel.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Icon(icon, color: cs.primary, size: 21),
            const SizedBox(width: 10),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            Text(value, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _ChannelRail extends StatelessWidget {
  const _ChannelRail({required this.channels, required this.allChannels});
  final List<Channel> channels, allChannels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final channel = channels[i];
          final index = allChannels.indexWhere((e) => e.key == channel.key);
          return ChannelCard(
            channel: channel,
            width: 112,
            onTap: () => openPlayer(context, allChannels, index < 0 ? 0 : index),
            onLong: () => showChannelActions(context, channel, onPlay: () => openPlayer(context, allChannels, index < 0 ? 0 : index)),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(double.infinity, 190, 26),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: box(double.infinity, 58)), const SizedBox(width: 10), Expanded(child: box(double.infinity, 58))]),
          const SizedBox(height: 24),
          box(150, 18, 8),
          const SizedBox(height: 12),
          Row(children: [for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(right: 12), child: box(78, 120))]),
          const SizedBox(height: 20),
          const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))),
        ],
      ),
    );
  }
}
