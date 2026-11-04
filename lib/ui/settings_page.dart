import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(c.t('settings'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          if (kEnableCustomSources)
          // ------------------------------------------------ sources
          _Section(icon: Icons.dns_rounded, title: c.t('sources'), children: [
            for (final s in c.sources) _SourceRow(source: s),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showSourceForm(context, null),
                icon: const Icon(Icons.add_rounded),
                label: Text(c.t('addSource')),
              ),
            ),
          ]),

          // ------------------------------------------------ appearance
          _Section(icon: Icons.palette_rounded, title: c.t('appearance'), children: [
            _Label(c.t('theme')),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kThemes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _ThemeThumb(index: i),
              ),
            ),
            const SizedBox(height: 14),
            _Label(c.t('accent')),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < kAccents.length; i++)
                  Tappable(
                    radius: 30,
                    onTap: () => c.setAccent(i),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Color(kAccents[i]), shape: BoxShape.circle),
                      child: c.accentIdx == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Label(c.t('language')),
            _Choices<String>(
              value: c.lang,
              options: const [('ar', 'العربية'), ('en', 'English')],
              onChanged: c.setLang,
            ),
          ]),

          // ------------------------------------------------ playback
          _Section(icon: Icons.play_circle_rounded, title: c.t('playback'), children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.t('hwAccel')),
              subtitle: Text(c.t('hwAccelSub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              value: c.hwAccel,
              onChanged: c.setHw,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.t('failover')),
              subtitle: Text(c.t('failoverSub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              value: c.failover,
              onChanged: c.setFailover,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.t('reconnect')),
              subtitle: Text(c.t('reconnectSub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              value: c.autoReconnect,
              onChanged: c.setAutoReconnect,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.t('landscape')),
              value: c.landscape,
              onChanged: c.setLandscape,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.t('gestures')),
              subtitle: Text(c.t('gesturesSub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              value: c.gestures,
              onChanged: c.setGestures,
            ),
            const SizedBox(height: 6),
            _Label(c.t('buffer')),
            _Choices<int>(
              value: c.bufferMb,
              options: const [(8, '8 MB'), (16, '16 MB'), (32, '32 MB'), (64, '64 MB')],
              onChanged: c.setBufferMb,
            ),
            const SizedBox(height: 12),
            _Label(c.t('defaultFit')),
            _Choices<int>(
              value: c.fitIdx,
              options: [
                (0, c.t('fit')),
                (1, c.t('zoom')),
                (2, c.t('stretch')),
                (3, '16:9'),
                (4, '4:3'),
              ],
              onChanged: c.setFit,
            ),
            const SizedBox(height: 12),
            _Label(c.t('seekStep')),
            _Choices<int>(
              value: c.seekSecs,
              options: const [(5, '5 s'), (10, '10 s'), (15, '15 s'), (30, '30 s')],
              onChanged: c.setSeekSecs,
            ),
            const SizedBox(height: 12),
            _Label(c.t('audioLang')),
            _Choices<String>(
              value: c.audioLang,
              options: [('', c.t('autoLang')), ('ar', c.t('ar')), ('en', c.t('en')), ('fr', c.t('fr')), ('tr', c.t('tr'))],
              onChanged: c.setAudioLang,
            ),
            const SizedBox(height: 12),
            _Label('${c.t('subSize')} · ${c.subSize.round()}'),
            Slider(
              min: 20,
              max: 56,
              divisions: 18,
              value: c.subSize.clamp(20, 56).toDouble(),
              onChanged: c.setSubSize,
            ),
          ]),

          // ------------------------------------------------ lists
          _Section(icon: Icons.view_list_rounded, title: c.t('lists'), children: [
            _Label(c.t('autoRefresh')),
            _Choices<int>(
              value: c.refreshHours,
              options: [(0, c.t('manual')), (3, '3 h'), (6, '6 h'), (12, '12 h'), (24, '24 h')],
              onChanged: c.setRefreshHours,
            ),
            const SizedBox(height: 12),
            _Label(c.t('sortGroups')),
            _Choices<String>(
              value: c.groupSort,
              options: [('count', c.t('mostItems')), ('az', c.t('az'))],
              onChanged: c.setGroupSort,
            ),
            const SizedBox(height: 12),
            _Label(c.t('hiddenWords')),
            Text(c.t('hiddenWordsSub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in c.hideWords)
                  InputChip(label: Text(w), onDeleted: () => c.removeHideWord(w)),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(c.t('addWord')),
                  onPressed: () => _addWord(context, c),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Action(
              icon: Icons.refresh_rounded,
              title: c.t('refreshNow'),
              sub: c.updated == null ? c.t('refreshNowSub') : '${c.t('updated')}: ${_fmt(c.updated!)}',
              onTap: () => c.loadChannels(force: true),
            ),
            _Action(
              icon: Icons.delete_sweep_rounded,
              title: c.t('clearCache'),
              sub: c.t('clearCacheSub'),
              onTap: () async {
                await c.clearCache();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.t('done'))));
              },
            ),
          ]),

          // ------------------------------------------------ parental
          _Section(icon: Icons.lock_rounded, title: c.t('parental'), children: [
            _Action(
              icon: Icons.pin_rounded,
              title: c.pin.isEmpty ? c.t('setPin') : c.t('changePin'),
              sub: c.t('pinSub'),
              onTap: () => _pinDialog(context, c),
            ),
          ]),

          // ------------------------------------------------ data
          _Section(icon: Icons.storage_rounded, title: c.t('data'), children: [
            _Action(icon: Icons.history_rounded, title: c.t('clearHistory'), sub: '${c.history.length}', onTap: c.clearHistory),
            _Action(icon: Icons.star_border_rounded, title: c.t('clearFavs'), sub: '${c.favorites.length}', onTap: c.clearFavorites),
          ]),

          // ------------------------------------------------ about
          _Section(icon: Icons.info_outline_rounded, title: c.t('about'), children: [
            const Text('KOBANI 4K · 2.0.0', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(c.t('disclaimer'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.4)),
          ]),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  static Future<void> _addWord(BuildContext context, AppController c) async {
    final ctrl = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.t('addWord')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: c.t('word')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(c.t('save'))),
        ],
      ),
    );
    ctrl.dispose();
    if (word != null) c.addHideWord(word);
  }

  static Future<void> _pinDialog(BuildContext context, AppController c) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.pin.isEmpty ? c.t('setPin') : c.t('changePin')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(labelText: c.t('newPin'), counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel'))),
          if (c.pin.isNotEmpty)
            TextButton(
              onPressed: () {
                c.setPin('');
                Navigator.pop(ctx);
              },
              child: Text(c.t('removePin')),
            ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4}$').hasMatch(ctrl.text)) {
                c.setPin(ctrl.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(c.t('save')),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}

// ===================================================================== pieces

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Choices<T> extends StatelessWidget {
  const _Choices({required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: o.$1 == value,
            showCheckmark: false,
            selectedColor: cs.primary.withValues(alpha: 0.25),
            side: BorderSide(color: o.$1 == value ? cs.primary : Colors.transparent),
            onSelected: (_) => onChanged(o.$1),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(sub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
      onTap: onTap,
    );
  }
}

class _ThemeThumb extends StatelessWidget {
  const _ThemeThumb({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final t = kThemes[index];
    final selected = c.themeIdx == index;
    return Tappable(
      radius: 16,
      onTap: () => c.setTheme(index),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              height: 82,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.bgTop, t.bgBottom]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? cs.primary : t.muted.withValues(alpha: 0.3), width: selected ? 3 : 1),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 46,
                height: 26,
                decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(8)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              c.t(t.key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: selected ? cs.primary : cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatefulWidget {
  const _SourceRow({required this.source});
  final SourceConfig source;

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  AccountInfo? _info;
  bool _asked = false;

  void _loadInfo(AppController c) {
    if (_asked) return;
    _asked = true;
    c.accountInfo(widget.source).then((v) {
      if (mounted) setState(() => _info = v);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final s = widget.source;
    final active = s.id == c.activeId;
    if (active && s.type == 'xtream') _loadInfo(c);
    final info = _info;
    final exp = info?.expiry;
    final expired = exp != null && exp.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tappable(
        radius: 16,
        onTap: () => c.selectSource(s.id),
        child: Container(
          color: active ? cs.primary.withValues(alpha: 0.16) : cs.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: active ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name.isEmpty ? s.url : s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${s.builtin ? c.t('builtinSource') : s.type.toUpperCase()}${active ? ' · ${c.t('active')}' : ''}${active && c.activeSource.id == s.id && c.totalCount > 0 ? ' · ${c.totalCount} ${c.t('items')}' : ''}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    if (info != null)
                      Text(
                        '${expired ? c.t('expired') : c.t('expires')}: ${exp == null ? '∞' : _SettingsDate.fmt(exp)} · ${c.t('status')}: ${info.status} · ${c.t('connections')}: ${info.activeConnections}/${info.maxConnections}',
                        style: TextStyle(fontSize: 11.5, color: expired ? const Color(0xFFFF6B6B) : cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (!s.builtin) IconButton(onPressed: () => showSourceForm(context, s), icon: const Icon(Icons.edit_rounded, size: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDate {
  static String fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

/// Add / edit dialog for M3U and Xtream sources.
Future<void> showSourceForm(BuildContext context, SourceConfig? existing) async {
  final c = AppScope.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final url = TextEditingController(text: existing?.url ?? '');
  final user = TextEditingController(text: existing?.user ?? '');
  final pass = TextEditingController(text: existing?.pass ?? '');
  var type = existing?.type ?? 'm3u';
  var format = existing?.format ?? 'm3u8';
  final formKey = GlobalKey<FormState>();

  String? req(String? v) => (v == null || v.trim().isEmpty) ? c.t('required') : null;

  final saved = await showDialog<SourceConfig>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? c.t('addSource') : c.t('editSource')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'm3u', label: Text('M3U')),
                    ButtonSegment(value: 'xtream', label: Text('Xtream')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => set(() => type = v.first),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: name, decoration: InputDecoration(labelText: c.t('name'))),
                const SizedBox(height: 10),
                TextFormField(
                  controller: url,
                  validator: req,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: type == 'm3u' ? c.t('m3uUrl') : c.t('serverUrl'), hintText: 'http://…'),
                ),
                if (type == 'xtream') ...[
                  const SizedBox(height: 10),
                  TextFormField(controller: user, validator: req, decoration: InputDecoration(labelText: c.t('username'))),
                  const SizedBox(height: 10),
                  TextFormField(controller: pass, validator: req, obscureText: true, decoration: InputDecoration(labelText: c.t('password'))),
                  const SizedBox(height: 12),
                  Text(c.t('streamFormat')),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'm3u8', label: Text('HLS (m3u8)')),
                      ButtonSegment(value: 'ts', label: Text('MPEG-TS')),
                    ],
                    selected: {format},
                    onSelectionChanged: (v) => set(() => format = v.first),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                c.deleteSource(existing.id);
                Navigator.pop(ctx);
              },
              child: Text(c.t('delete'), style: const TextStyle(color: Color(0xFFFF6B6B))),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel'))),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                ctx,
                SourceConfig(
                  id: existing?.id ?? 's${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                  name: name.text.trim().isEmpty ? url.text.trim() : name.text.trim(),
                  type: type,
                  url: url.text.trim(),
                  user: type == 'xtream' ? user.text.trim() : '',
                  pass: type == 'xtream' ? pass.text.trim() : '',
                  format: format,
                ),
              );
            },
            child: Text(c.t('save')),
          ),
        ],
      ),
    ),
  );

  name.dispose();
  url.dispose();
  user.dispose();
  pass.dispose();
  if (saved != null) {
    c.saveSource(saved);
    if (existing == null) c.selectSource(saved.id);
  }
}
