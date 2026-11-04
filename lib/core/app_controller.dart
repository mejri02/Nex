import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/live_tv_service.dart';
import '../services/m3u_parser.dart';
import '../services/xtream_service.dart';
import 'models.dart';
import 'strings.dart';

/// Custom M3U/Xtream sources are disabled: the app uses only its original source.
const bool kEnableCustomSources = false;

/// One object that owns settings, sources, channels, favorites and history.
class AppController extends ChangeNotifier {
  AppController._(this._p);

  final SharedPreferences _p;
  final http.Client _client = http.Client();

  static Future<AppController> create() async {
    final c = AppController._(await SharedPreferences.getInstance());
    c._restore();
    return c;
  }

  // ---------------------------------------------------------------- settings
  String lang = 'ar';
  int themeIdx = 0;
  int accentIdx = 0;
  bool gridView = true;
  String groupSort = 'count'; // count | az
  List<String> hideWords = ['KURD', 'MUSIC'];
  int refreshHours = 12;

  bool hwAccel = true;
  int bufferMb = 32;
  bool failover = true;
  bool autoReconnect = true;
  bool landscape = true;
  bool gestures = true;
  int seekSecs = 10;
  String audioLang = '';
  double subSize = 32;
  int fitIdx = 0;

  String pin = '';

  List<SourceConfig> sources = [
    const SourceConfig(id: SourceConfig.builtinId, name: 'KOBANI 4K', type: 'builtin'),
  ];
  String activeId = SourceConfig.builtinId;

  // ---------------------------------------------------------------- data
  List<Channel> _all = [];
  bool loading = false;
  String? error;
  DateTime? updated;
  List<Channel> favorites = [];
  List<Channel> history = [];

  // transient UI state shared between tabs
  String groupFilter = '';
  String query = '';

  final Set<String> _unlocked = {};
  List<Channel>? _base;
  List<Channel>? _visible;
  List<GroupInfo>? _groups;
  int _loadSeq = 0;

  String t(String key) => tr(lang, key);
  bool get rtl => lang == 'ar';

  SourceConfig get activeSource =>
      sources.firstWhere((s) => s.id == activeId, orElse: () => sources.first);

  // ---------------------------------------------------------------- restore / save
  void _restore() {
    lang = _p.getString('lang') ?? lang;
    themeIdx = (_p.getInt('theme') ?? 0).clamp(0, 5);
    accentIdx = (_p.getInt('accent') ?? 0).clamp(0, 7);
    gridView = _p.getBool('grid') ?? gridView;
    groupSort = _p.getString('groupSort') ?? groupSort;
    hideWords = _p.getStringList('hide') ?? hideWords;
    refreshHours = _p.getInt('refresh') ?? refreshHours;
    hwAccel = _p.getBool('hw') ?? hwAccel;
    bufferMb = _p.getInt('bufferMb') ?? bufferMb;
    failover = _p.getBool('failover') ?? failover;
    autoReconnect = _p.getBool('reconnect') ?? autoReconnect;
    landscape = _p.getBool('landscape') ?? landscape;
    gestures = _p.getBool('gestures') ?? gestures;
    seekSecs = _p.getInt('seekSecs') ?? seekSecs;
    audioLang = _p.getString('audioLang') ?? audioLang;
    subSize = _p.getDouble('subSize') ?? subSize;
    fitIdx = (_p.getInt('fit') ?? 0).clamp(0, 4);
    pin = _p.getString('pin') ?? '';
    activeId = _p.getString('active') ?? activeId;

    final srcJson = _p.getString('sources');
    if (srcJson != null) {
      try {
        final list = <SourceConfig>[
          for (final e in jsonDecode(srcJson) as List) SourceConfig.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
        if (list.isNotEmpty) sources = list;
      } catch (_) {}
    }
    if (!sources.any((s) => s.builtin)) {
      sources = [const SourceConfig(id: SourceConfig.builtinId, name: 'KOBANI 4K', type: 'builtin'), ...sources];
    }
    if (!kEnableCustomSources) {
      sources = [sources.firstWhere((s) => s.builtin)];
    }
    if (!sources.any((s) => s.id == activeId)) activeId = sources.first.id;

    favorites = _readChannels('favs');
    history = _readChannels('history');
  }

  List<Channel> _readChannels(String key) {
    final raw = _p.getString(key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) Channel.fromJson(Map<String, dynamic>.from(e as Map)),
      ].where((c) => c.sources.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  void _writeChannels(String key, List<Channel> list) =>
      _p.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));

  void _saveSources() => _p.setString('sources', jsonEncode(sources.map((e) => e.toJson()).toList()));

  void _touch() {
    _base = null;
    _visible = null;
    _groups = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- simple setters
  void setLang(String v) { lang = v; _p.setString('lang', v); notifyListeners(); }
  void setTheme(int v) { themeIdx = v; _p.setInt('theme', v); notifyListeners(); }
  void setAccent(int v) { accentIdx = v; _p.setInt('accent', v); notifyListeners(); }
  void setGrid(bool v) { gridView = v; _p.setBool('grid', v); notifyListeners(); }
  void setGroupSort(String v) { groupSort = v; _p.setString('groupSort', v); _touch(); }
  void setRefreshHours(int v) { refreshHours = v; _p.setInt('refresh', v); notifyListeners(); }
  void setHw(bool v) { hwAccel = v; _p.setBool('hw', v); notifyListeners(); }
  void setBufferMb(int v) { bufferMb = v; _p.setInt('bufferMb', v); notifyListeners(); }
  void setFailover(bool v) { failover = v; _p.setBool('failover', v); notifyListeners(); }
  void setAutoReconnect(bool v) { autoReconnect = v; _p.setBool('reconnect', v); notifyListeners(); }
  void setLandscape(bool v) { landscape = v; _p.setBool('landscape', v); notifyListeners(); }
  void setGestures(bool v) { gestures = v; _p.setBool('gestures', v); notifyListeners(); }
  void setSeekSecs(int v) { seekSecs = v; _p.setInt('seekSecs', v); notifyListeners(); }
  void setAudioLang(String v) { audioLang = v; _p.setString('audioLang', v); notifyListeners(); }
  void setSubSize(double v) { subSize = v; _p.setDouble('subSize', v); notifyListeners(); }
  void setFit(int v) { fitIdx = v; _p.setInt('fit', v); notifyListeners(); }

  void setGroupFilter(String g) { groupFilter = g; notifyListeners(); }
  void setQuery(String q) { query = q; notifyListeners(); }

  void addHideWord(String w) {
    final word = w.trim();
    if (word.isEmpty || hideWords.any((e) => e.toLowerCase() == word.toLowerCase())) return;
    hideWords = [...hideWords, word];
    _p.setStringList('hide', hideWords);
    _touch();
  }

  void removeHideWord(String w) {
    hideWords = hideWords.where((e) => e != w).toList();
    _p.setStringList('hide', hideWords);
    _touch();
  }

  // ---------------------------------------------------------------- parental
  static final RegExp _adult = RegExp(r'\b(adult|adults|xxx|porn)\b|18\s*\+|\+\s*18', caseSensitive: false);

  bool isAdultGroup(String g) => _adult.hasMatch(g);
  bool isLocked(String g) => pin.isNotEmpty && isAdultGroup(g) && !_unlocked.contains(g);

  bool unlockGroup(String g, String attempt) {
    if (attempt != pin) return false;
    _unlocked.add(g);
    _touch();
    return true;
  }

  void setPin(String v) {
    pin = v;
    _unlocked.clear();
    _p.setString('pin', v);
    _touch();
  }

  // ---------------------------------------------------------------- sources
  void selectSource(String id) {
    if (id == activeId) return;
    activeId = id;
    _p.setString('active', id);
    _all = [];
    groupFilter = '';
    _touch();
    loadChannels();
  }

  void saveSource(SourceConfig s) {
    final i = sources.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      sources = [...sources]..[i] = s;
    } else {
      sources = [...sources, s];
    }
    _saveSources();
    _p.remove('cache_${s.id}');
    if (s.id == activeId) {
      _all = [];
      _touch();
      loadChannels(force: true);
    } else {
      notifyListeners();
    }
  }

  void deleteSource(String id) {
    final s = sources.firstWhere((e) => e.id == id, orElse: () => sources.first);
    if (s.builtin) return;
    sources = sources.where((e) => e.id != id).toList();
    _saveSources();
    _p.remove('cache_$id');
    _p.remove('cache_ts_$id');
    if (activeId == id) {
      selectSource(sources.first.id);
    } else {
      notifyListeners();
    }
  }

  Future<AccountInfo> accountInfo(SourceConfig s) => XtreamService(_client).accountInfo(s);

  // ---------------------------------------------------------------- channels
  Future<List<Channel>> _fetch(SourceConfig s) async {
    switch (s.type) {
      case 'xtream':
        return XtreamService(_client).fetchLive(s);
      case 'm3u':
        final uri = Uri.parse(XtreamService.normalizeBase(s.url));
        final r = await _client.get(uri).timeout(const Duration(seconds: 60));
        if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
        final list = parseM3u(utf8.decode(r.bodyBytes, allowMalformed: true), idPrefix: s.id);
        if (list.isEmpty) throw Exception('No channels found in the playlist');
        return list;
      default:
        return LiveTvService(_client).fetchChannels();
    }
  }

  List<Channel>? _readCache(String id) {
    final raw = _p.getString('cache_$id');
    if (raw == null) return null;
    try {
      final list = [
        for (final e in jsonDecode(raw) as List) Channel.fromJson(Map<String, dynamic>.from(e as Map)),
      ].where((c) => c.sources.isNotEmpty).toList();
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadChannels({bool force = false}) async {
    final src = activeSource;
    final seq = ++_loadSeq;
    final cached = force ? null : _readCache(src.id);
    final ts = _p.getInt('cache_ts_${src.id}') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    final fresh = cached != null && (refreshHours == 0 || age < refreshHours * 3600000);

    if (cached != null && _all.isEmpty) {
      _all = cached;
      updated = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
    }
    if (fresh) {
      loading = false;
      error = null;
      _touch();
      return;
    }

    loading = true;
    error = null;
    _touch();
    try {
      final list = await _fetch(src);
      if (seq != _loadSeq) return;
      _all = list;
      updated = DateTime.now();
      final json = jsonEncode(list.map((e) => e.toJson()).toList());
      if (json.length < 6000000) {
        await _p.setString('cache_${src.id}', json);
        await _p.setInt('cache_ts_${src.id}', updated!.millisecondsSinceEpoch);
      }
      error = null;
    } catch (e) {
      if (seq != _loadSeq) return;
      error = _all.isEmpty ? '$e'.replaceFirst('Exception: ', '') : null;
    }
    loading = false;
    _touch();
  }

  Future<void> clearCache() async {
    for (final s in sources) {
      await _p.remove('cache_${s.id}');
      await _p.remove('cache_ts_${s.id}');
    }
  }

  // ---------------------------------------------------------------- views of the data
  bool _hidden(Channel c) {
    if (hideWords.isEmpty) return false;
    final n = c.name.toLowerCase(), g = c.group.toLowerCase();
    for (final w in hideWords) {
      final x = w.toLowerCase();
      if (n.contains(x) || g.contains(x)) return true;
    }
    return false;
  }

  List<Channel> get _baseList => _base ??= _all.where((c) => !_hidden(c)).toList();

  /// Everything the user may see right now (hidden words and locked groups removed).
  List<Channel> get visible => _visible ??= _baseList.where((c) => !isLocked(c.group)).toList();

  int get totalCount => _baseList.length;

  List<GroupInfo> get groups {
    final cached = _groups;
    if (cached != null) return cached;
    final counts = <String, int>{};
    for (final c in _baseList) {
      counts[c.group] = (counts[c.group] ?? 0) + 1;
    }
    final list = [for (final e in counts.entries) GroupInfo(e.key, e.value, false)];
    if (groupSort == 'az') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) => b.count.compareTo(a.count));
    }
    return _groups = list;
  }

  /// Channels for the Channels tab: group + search applied.
  List<Channel> filtered() {
    final q = query.trim().toLowerCase();
    Iterable<Channel> it;
    if (groupFilter.isEmpty) {
      it = visible;
    } else if (isLocked(groupFilter)) {
      it = const [];
    } else {
      it = _baseList.where((c) => c.group == groupFilter);
    }
    if (q.isNotEmpty) it = it.where((c) => c.name.toLowerCase().contains(q));
    return it.toList();
  }

  List<Channel> channelsOfGroup(String g, {int limit = 0}) {
    if (isLocked(g)) return const [];
    final it = _baseList.where((c) => c.group == g);
    return (limit > 0 ? it.take(limit) : it).toList();
  }

  // ---------------------------------------------------------------- favorites / history
  bool isFav(Channel c) => favorites.any((e) => e.key == c.key);

  void toggleFav(Channel c) {
    if (isFav(c)) {
      favorites = favorites.where((e) => e.key != c.key).toList();
    } else {
      favorites = [c, ...favorites];
    }
    _writeChannels('favs', favorites);
    notifyListeners();
  }

  void clearFavorites() {
    favorites = [];
    _writeChannels('favs', favorites);
    notifyListeners();
  }

  void pushHistory(Channel c) {
    history = [c, ...history.where((e) => e.key != c.key)].take(24).toList();
    _writeChannels('history', history);
    notifyListeners();
  }

  void clearHistory() {
    history = [];
    _writeChannels('history', history);
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// Same as [of] but safe to call from initState (does not subscribe).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.notifier!;
  }
}
