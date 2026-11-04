import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/models.dart';

/// Tap target that also looks right with a TV remote (visible focus ring + zoom).
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.radius = 16,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool autofocus;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final r = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _focused ? 1.05 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: _focused ? accent : Colors.transparent, width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              autofocus: widget.autofocus,
              onTap: widget.onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      widget.onTap!();
                    },
              onLongPress: widget.onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      widget.onLongPress!();
                    },
              onFocusChange: (v) => setState(() => _focused = v),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

const List<List<Color>> _tilePalette = [
  [Color(0xFFE5173F), Color(0xFFFF7A59)],
  [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
  [Color(0xFF10B981), Color(0xFF06B6D4)],
  [Color(0xFFF59E0B), Color(0xFFEF4444)],
  [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  [Color(0xFF3B82F6), Color(0xFF22D3EE)],
];

List<Color> paletteFor(String s) => _tilePalette[(s.hashCode & 0x7fffffff) % _tilePalette.length];

/// Channel logo on a light tile, with a clean fallback when it is missing or fails.
class Logo extends StatelessWidget {
  const Logo({super.key, required this.url, this.size = 56, this.radius = 14, this.name = ''});
  final String url;
  final double size, radius;
  final String name;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: paletteFor(name)),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '' : String.fromCharCode(name.runes.first).toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.startsWith('http')
            ? ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.1),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    cacheWidth: (size * 3).round(),
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => fallback,
                    loadingBuilder: (c, child, p) => p == null ? child : fallback,
                  ),
                ),
              )
            : fallback,
      ),
    );
  }
}

/// Poster-like card used in horizontal rows and grids.
class ChannelCard extends StatelessWidget {
  const ChannelCard({super.key, required this.channel, required this.onTap, this.onLong, this.width});
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final fav = c.isFav(channel);
    return SizedBox(
      width: width,
      child: Tappable(
        onTap: onTap,
        onLongPress: onLong,
        radius: 18,
        child: Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(builder: (context, box) {
                final s = box.maxWidth;
                return Stack(
                  children: [
                    Logo(url: channel.logo, size: s, radius: 14, name: channel.name),
                    if (fav)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC83D)),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  const ChannelTile({super.key, required this.channel, required this.onTap, this.onLong});
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onLong;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final fav = c.isFav(channel);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Tappable(
        onTap: onTap,
        onLongPress: onLong,
        radius: 18,
        child: Container(
          color: cs.surface,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Logo(url: channel.logo, size: 52, name: channel.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      channel.group.isEmpty ? c.t('uncategorized') : channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (channel.sources.length > 1)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('${channel.sources.length}×', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700)),
                ),
              IconButton(
                onPressed: () => c.toggleFav(channel),
                icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded, color: fav ? const Color(0xFFFFC83D) : cs.onSurfaceVariant),
              ),
              Icon(Icons.play_circle_fill_rounded, color: cs.primary, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.onTap, this.width});
  final GroupInfo group;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final pal = paletteFor(group.name);
    final locked = c.isLocked(group.name);
    return SizedBox(
      width: width,
      child: Tappable(
        onTap: onTap,
        radius: 20,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pal[0].withValues(alpha: 0.9), pal[1].withValues(alpha: 0.9)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(locked ? Icons.lock_rounded : Icons.live_tv_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name.isEmpty ? c.t('uncategorized') : group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, height: 1.15),
                  ),
                  const SizedBox(height: 2),
                  Text('${group.count} ${c.t('items')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: TextStyle(color: cs.primary))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Long-press / "more" menu for a channel.
Future<void> showChannelActions(BuildContext context, Channel ch, {required VoidCallback onPlay}) {
  final c = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Logo(url: ch.logo, size: 44, name: ch.name),
            title: Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(ch.group),
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: Text(c.t('play')),
            onTap: () {
              Navigator.pop(ctx);
              onPlay();
            },
          ),
          ListTile(
            leading: Icon(c.isFav(ch) ? Icons.star_rounded : Icons.star_border_rounded),
            title: Text(c.isFav(ch) ? c.t('removeFav') : c.t('addFav')),
            onTap: () {
              c.toggleFav(ch);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

/// Asks for the parental PIN. Returns true when the group got unlocked.
Future<bool> askPin(BuildContext context, String group) async {
  final c = AppScope.of(context);
  final ctrl = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(c.t('enterPin')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(errorText: err, counterText: ''),
          onSubmitted: (_) {
            if (c.unlockGroup(group, ctrl.text)) {
              Navigator.pop(ctx, true);
            } else {
              set(() => err = c.t('wrongPin'));
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t('cancel'))),
          FilledButton(
            onPressed: () {
              if (c.unlockGroup(group, ctrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                set(() => err = c.t('wrongPin'));
              }
            },
            child: Text(c.t('confirm')),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return ok ?? false;
}
