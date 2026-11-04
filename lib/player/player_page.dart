import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../ui/widgets.dart';

Future<void> openPlayer(BuildContext context, List<Channel> playlist, int index) {
  if (playlist.isEmpty) return Future.value();
  final i = index < 0 ? 0 : (index >= playlist.length ? playlist.length - 1 : index);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => PlayerPage(playlist: playlist, index: i),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// Picture modes: fit, zoom (crop), stretch, forced 16:9 and 4:3.
const List<(BoxFit, double?)> _fits = [
  (BoxFit.contain, null),
  (BoxFit.cover, null),
  (BoxFit.fill, null),
  (BoxFit.fill, 16 / 9),
  (BoxFit.fill, 4 / 3),
];
const List<String> _fitKeys = ['fit', 'zoom', 'stretch', '16:9', '4:3'];

class _Opt {
  const _Opt(this.label, {this.sub, this.selected = false, this.onTap, this.header = false});
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
  final bool header;
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.playlist, required this.index});
  final List<Channel> playlist;
  final int index;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AppController app;
  late final Player player;
  late final VideoController video;

  // current channel / source
  late int index;
  late Channel ch;
  late List<StreamSource> sources;
  int selected = 0;
  final Set<int> _failed = {};
  int _attempt = 0;
  int _reconnects = 0;
  DateTime _lastStart = DateTime.now();
  bool _started = false;
  bool _historyAdded = false;
  bool _audioPicked = false;
  Timer? _watchdog;

  // player state
  bool playing = false;
  bool buffering = false;
  bool loading = true;
  String? error;
  Duration duration = Duration.zero;
  int vidW = 0, vidH = 0;
  Tracks tracks = const Tracks();
  Track curTrack = const Track();
  double rate = 1.0;
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferPos = ValueNotifier(Duration.zero);
  final List<StreamSubscription<dynamic>> _subs = [];

  // ui state
  bool controls = true;
  bool locked = false;
  bool panel = false;
  bool _modal = false;
  int fitIdx = 0;
  double vol = 100;
  double _lastVol = 100;
  double dim = 0; // 0 = normal, up to .75 = dark
  int sleepMin = 0;
  double? _dragValue;
  Timer? _hide;
  Timer? _sleep;
  Timer? _flashTimer;
  String? flashText;
  IconData? flashIcon;
  Offset _tapPos = Offset.zero;
  bool _dragLeft = false;
  int _dragSeekMs = 0;
  bool _landscape = true;
  final FocusNode _focus = FocusNode();
  late final ScrollController _panelScroll;

  bool get isLive => duration.inSeconds < 1;

  @override
  void initState() {
    super.initState();
    app = AppScope.read(context);
    index = widget.index;
    ch = widget.playlist[index];
    sources = ch.sources;
    fitIdx = app.fitIdx;
    _landscape = app.landscape;
    final startOffset = index * 64.0 - 120;
    _panelScroll = ScrollController(initialScrollOffset: startOffset < 0 ? 0.0 : startOffset);

    player = Player(configuration: PlayerConfiguration(bufferSize: app.bufferMb * 1024 * 1024));
    video = VideoController(
      player,
      configuration: VideoControllerConfiguration(enableHardwareAcceleration: app.hwAccel),
    );
    vol = player.state.volume;

    _subs.addAll([
      player.stream.playing.listen((v) {
        if (!mounted) return;
        setState(() => playing = v);
        _scheduleHide();
      }),
      player.stream.buffering.listen((v) {
        if (mounted) setState(() => buffering = v);
      }),
      player.stream.position.listen((v) {
        position.value = v;
        if (!_started && v > Duration.zero) _markStarted();
      }),
      player.stream.buffer.listen((v) => bufferPos.value = v),
      player.stream.duration.listen((v) {
        if (mounted) setState(() => duration = v);
      }),
      player.stream.width.listen((v) {
        if (!mounted) return;
        setState(() => vidW = v ?? 0);
        if ((v ?? 0) > 0) _markStarted();
      }),
      player.stream.height.listen((v) {
        if (mounted) setState(() => vidH = v ?? 0);
      }),
      player.stream.tracks.listen((t) {
        if (!mounted) return;
        setState(() => tracks = t);
        _autoPickAudio(t);
      }),
      player.stream.track.listen((t) {
        if (mounted) setState(() => curTrack = t);
      }),
      player.stream.volume.listen((v) => vol = v),
      player.stream.rate.listen((v) {
        if (mounted) setState(() => rate = v);
      }),
      player.stream.error.listen(_onError),
      player.stream.completed.listen(_onCompleted),
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyOrientation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(0));
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _hide?.cancel();
    _sleep?.cancel();
    _flashTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    position.dispose();
    bufferPos.dispose();
    _focus.dispose();
    _panelScroll.dispose();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  // ------------------------------------------------------------ orientation
  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _landscape
          ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [DeviceOrientation.portraitUp],
    );
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
    _show();
  }

  // ------------------------------------------------------------ opening / failover
  Future<void> _open(int srcIdx) async {
    if (!mounted) return;
    final attempt = ++_attempt;
    _watchdog?.cancel();
    final s = sources[srcIdx];
    _started = false;
    _audioPicked = false;
    setState(() {
      selected = srcIdx;
      loading = true;
      error = null;
      vidW = 0;
      vidH = 0;
      position.value = Duration.zero;
    });
    if (s.drm) {
      _fail(srcIdx, attempt, app.t('drmBlocked'));
      return;
    }
    _watchdog = Timer(const Duration(seconds: 25), () => _fail(srcIdx, attempt, app.t('timeout')));
    try {
      final headers = <String, String>{
        if (s.userAgent.isNotEmpty) 'User-Agent': s.userAgent,
        if (s.referer.isNotEmpty) 'Referer': s.referer,
      };
      await player.open(Media(s.url, httpHeaders: headers));
    } catch (e) {
      _fail(srcIdx, attempt, '$e');
    }
  }

  void _markStarted() {
    if (_started || !mounted) return;
    _started = true;
    _watchdog?.cancel();
    _lastStart = DateTime.now();
    if (!_historyAdded) {
      _historyAdded = true;
      app.pushHistory(ch);
    }
    setState(() {
      loading = false;
      error = null;
    });
  }

  void _fail(int srcIdx, int attempt, String reason) {
    if (!mounted || attempt != _attempt || _started) return;
    _watchdog?.cancel();
    _failed.add(srcIdx);
    final next = app.failover
        ? List<int>.generate(sources.length, (i) => i).firstWhere((i) => !_failed.contains(i), orElse: () => -1)
        : -1;
    if (next != -1) {
      _flash(Icons.swap_horiz_rounded, '${app.t('switching')} ${sources[next].name}');
      _open(next);
    } else {
      setState(() {
        loading = false;
        error = sources.length > 1 && app.failover ? '${app.t('allFailed')}\n$reason' : reason;
      });
      _show();
    }
  }

  void _onError(String e) {
    if (!mounted || _started) return; // errors while playing are handled by "completed"
    _fail(selected, _attempt, e);
  }

  void _onCompleted(bool done) {
    if (!done || !mounted || !_started) return;
    if (isLive && app.autoReconnect) _reconnect();
  }

  Future<void> _reconnect() async {
    if (DateTime.now().difference(_lastStart).inSeconds > 60) _reconnects = 0;
    _reconnects++;
    if (_reconnects > 3) {
      _started = false;
      _fail(selected, _attempt, app.t('playFailed'));
      return;
    }
    _flash(Icons.sync_rounded, app.t('reconnecting'), ms: 2500);
    await Future<void>.delayed(Duration(seconds: _reconnects));
    if (!mounted) return;
    _open(selected);
  }

  void _retry() {
    _failed.clear();
    _reconnects = 0;
    _open(selected);
  }

  void _nextServer() {
    if (sources.length < 2) return;
    _failed.clear();
    _open((selected + 1) % sources.length);
  }

  void _loadChannel(int i) {
    final len = widget.playlist.length;
    final n = ((i % len) + len) % len;
    setState(() {
      index = n;
      ch = widget.playlist[n];
      sources = ch.sources;
      _historyAdded = false;
      duration = Duration.zero;
    });
    _failed.clear();
    _reconnects = 0;
    _flash(Icons.live_tv_rounded, ch.name, ms: 1400);
    _open(0);
  }

  void _zap(int delta) {
    if (widget.playlist.length < 2) return;
    _loadChannel(index + delta);
  }

  void _autoPickAudio(Tracks t) {
    if (_audioPicked || app.audioLang.isEmpty) return;
    final real = t.audio.where((a) => a.id != 'auto' && a.id != 'no').toList();
    if (real.length < 2) return;
    _audioPicked = true;
    final want = app.audioLang.toLowerCase();
    for (final a in real) {
      final l = (a.language ?? '').toLowerCase();
      final title = (a.title ?? '').toLowerCase();
      if (l.startsWith(want) || title.contains(want)) {
        player.setAudioTrack(a);
        return;
      }
    }
  }

  // ------------------------------------------------------------ controls visibility
  void _show() {
    if (!mounted) return;
    setState(() => controls = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hide?.cancel();
    if (!playing || panel || _modal || _dragValue != null) return;
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && !_modal && !panel) setState(() => controls = false);
    });
  }

  void _closePanel() {
    setState(() => panel = false);
    _focus.requestFocus();
    _show();
  }

  void _toggleControls() {
    if (panel) {
      _closePanel();
      return;
    }
    if (controls) {
      _hide?.cancel();
      setState(() => controls = false);
    } else {
      _show();
    }
  }

  void _flash(IconData? icon, String text, {int ms = 900}) {
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      flashIcon = icon;
      flashText = text;
    });
    _flashTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => flashText = null);
    });
  }

  // ------------------------------------------------------------ actions
  void _seekBy(int secs) {
    if (isLive) return;
    final target = position.value + Duration(seconds: secs);
    final clamped = target < Duration.zero ? Duration.zero : (target > duration ? duration : target);
    player.seek(clamped);
    _flash(secs > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, '${secs > 0 ? '+' : ''}$secs s');
  }

  void _togglePlay() {
    player.playOrPause();
    _show();
  }

  void _cycleFit() {
    setState(() => fitIdx = (fitIdx + 1) % _fits.length);
    final k = _fitKeys[fitIdx];
    _flash(Icons.aspect_ratio_rounded, k.contains(':') ? k : app.t(k));
    _show();
  }

  void _setSleep(int min) {
    _sleep?.cancel();
    setState(() => sleepMin = min);
    if (min > 0) {
      _sleep = Timer(Duration(minutes: min), () {
        if (!mounted) return;
        player.pause();
        _flash(Icons.bedtime_rounded, app.t('sleepDone'), ms: 2500);
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      });
    }
  }

  String get _resLabel {
    if (vidH <= 0) return '';
    if (vidH >= 2000) return '4K';
    if (vidH >= 1400) return '2K';
    if (vidH >= 1000) return 'FHD';
    if (vidH >= 700) return 'HD';
    return 'SD';
  }

  // ------------------------------------------------------------ sheets
  Future<void> _sheet(String title, List<_Opt> opts) async {
    _modal = true;
    _hide?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in opts)
                        if (o.header)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                            child: Text(o.label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                          )
                        else
                          ListTile(
                            dense: true,
                            leading: Icon(
                              o.selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: o.selected ? cs.primary : cs.onSurfaceVariant,
                            ),
                            title: Text(o.label),
                            subtitle: o.sub == null ? null : Text(o.sub!),
                            onTap: () {
                              Navigator.pop(ctx);
                              o.onTap?.call();
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _modal = false;
    _show();
  }

  String _trackLabel(String? title, String? lang, int i) {
    final parts = <String>[
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty && lang != title) lang.toUpperCase(),
    ];
    return parts.isEmpty ? '#${i + 1}' : parts.join(' · ');
  }

  void _tracksSheet() {
    final audio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subs = tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final vids = tracks.video.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final opts = <_Opt>[
      _Opt(app.t('audio'), header: true),
      _Opt(app.t('auto'), selected: curTrack.audio.id == 'auto', onTap: () => player.setAudioTrack(AudioTrack.auto())),
      for (var i = 0; i < audio.length; i++)
        _Opt(
          _trackLabel(audio[i].title, audio[i].language, i),
          sub: audio[i].codec,
          selected: curTrack.audio.id == audio[i].id,
          onTap: () => player.setAudioTrack(audio[i]),
        ),
      _Opt(app.t('subtitles'), header: true),
      _Opt(app.t('off'), selected: curTrack.subtitle.id == 'no', onTap: () => player.setSubtitleTrack(SubtitleTrack.no())),
      for (var i = 0; i < subs.length; i++)
        _Opt(
          _trackLabel(subs[i].title, subs[i].language, i),
          selected: curTrack.subtitle.id == subs[i].id,
          onTap: () => player.setSubtitleTrack(subs[i]),
        ),
      if (vids.length > 1) ...[
        _Opt(app.t('quality'), header: true),
        _Opt(app.t('auto'), selected: curTrack.video.id == 'auto', onTap: () => player.setVideoTrack(VideoTrack.auto())),
        for (var i = 0; i < vids.length; i++)
          _Opt(
            vids[i].h != null ? '${vids[i].h}p${vids[i].fps != null ? ' · ${vids[i].fps!.round()} fps' : ''}' : _trackLabel(vids[i].title, vids[i].language, i),
            sub: vids[i].bitrate != null ? '${(vids[i].bitrate! / 1000).round()} kbps' : null,
            selected: curTrack.video.id == vids[i].id,
            onTap: () => player.setVideoTrack(vids[i]),
          ),
      ],
    ];
    _sheet(app.t('tracks'), opts);
  }

  void _serverSheet() {
    _sheet(app.t('server'), [
      for (var i = 0; i < sources.length; i++)
        _Opt(
          sources[i].name,
          sub: sources[i].drm ? 'DRM' : null,
          selected: i == selected,
          onTap: () {
            _failed.clear();
            _open(i);
          },
        ),
    ]);
  }

  void _moreSheet() {
    _sheet(app.t('more'), [
      if (!isLive) ...[
        _Opt(app.t('speed'), header: true),
        for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          _Opt('${r}x', selected: (rate - r).abs() < 0.01, onTap: () => player.setRate(r)),
      ],
      _Opt(app.t('sleepTimer'), header: true),
      _Opt(app.t('off'), selected: sleepMin == 0, onTap: () => _setSleep(0)),
      for (final m in const [15, 30, 60, 90, 120])
        _Opt('$m ${app.t('minutes')}', selected: sleepMin == m, onTap: () => _setSleep(m)),
    ]);
  }

  // ------------------------------------------------------------ gestures
  void _onVDragStart(DragStartDetails d, double width) {
    _dragLeft = d.localPosition.dx < width / 2;
  }

  void _onVDragUpdate(DragUpdateDetails d, double height) {
    final delta = -d.delta.dy / (height * 0.7);
    if (_dragLeft) {
      setState(() => dim = (dim - delta).clamp(0.0, 0.75));
      _flash(Icons.brightness_6_rounded, '${((1 - dim / 0.75) * 100).round()}%', ms: 600);
    } else {
      final v = (vol + delta * 100).clamp(0.0, 100.0);
      vol = v;
      player.setVolume(v);
      _flash(v == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, '${v.round()}%', ms: 600);
    }
  }

  void _onHDragUpdate(DragUpdateDetails d) {
    if (isLive) return;
    _dragSeekMs += (d.delta.dx * 150).round();
    final s = (_dragSeekMs / 1000).round();
    _flash(s >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, '${s > 0 ? '+' : ''}$s s', ms: 600);
  }

  void _onHDragEnd() {
    if (isLive || _dragSeekMs == 0) return;
    final target = position.value + Duration(milliseconds: _dragSeekMs);
    _dragSeekMs = 0;
    player.seek(target < Duration.zero ? Duration.zero : (target > duration ? duration : target));
  }

  void _onDoubleTap(double width) {
    if (isLive || !app.gestures) return;
    _seekBy(_tapPos.dx < width / 2 ? -app.seekSecs : app.seekSecs);
  }

  // ------------------------------------------------------------ keyboard / remote
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (locked) {
      _show();
      return KeyEventResult.handled;
    }
    if (panel) {
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.escape) {
        _closePanel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // let focus move inside the list
    }
    if (error != null && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter)) {
      return KeyEventResult.ignored; // lets the focused "Retry" button act
    }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaPlay) {
      player.play();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaPause) {
      player.pause();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.mediaTrackNext) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown || k == LogicalKeyboardKey.mediaTrackPrevious) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (isLive) {
        if (widget.playlist.length > 1) setState(() => panel = true);
      } else {
        _seekBy(app.seekSecs);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (isLive) {
        _tracksSheet();
      } else {
        _seekBy(-app.seekSecs);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(app.seekSecs);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaRewind) {
      _seekBy(-app.seekSecs);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fit, ratio) = _fits[fitIdx];
    final spinner = (loading || buffering) && error == null;

    return PopScope(
      canPop: !panel && !locked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (locked) {
          _flash(Icons.lock_rounded, app.t('unlockHint'), ms: 1500);
        } else if (panel) {
          _closePanel();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                // ---- video
                AnimatedOpacity(
                  opacity: _started ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: Video(
                  controller: video,
                  controls: NoVideoControls,
                  fit: fit,
                  aspectRatio: ratio,
                  fill: Colors.black,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(
                      fontSize: app.subSize,
                      height: 1.3,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      backgroundColor: const Color(0x99000000),
                    ),
                    textAlign: TextAlign.center,
                    padding: EdgeInsets.fromLTRB(24, 0, 24, controls ? 96 : 32),
                  ),
                  ),
                ),

                // ---- software brightness (dim) layer
                if (dim > 0) IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: dim))),

                // ---- gesture layer
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTapDown: (!isLive && app.gestures && !locked) ? (d) => _tapPos = d.localPosition : null,
                    onDoubleTap: (!isLive && app.gestures && !locked) ? () => _onDoubleTap(w) : null,
                    onVerticalDragStart: (app.gestures && !locked && !panel) ? (d) => _onVDragStart(d, w) : null,
                    onVerticalDragUpdate: (app.gestures && !locked && !panel) ? (d) => _onVDragUpdate(d, h) : null,
                    onHorizontalDragUpdate: (app.gestures && !locked && !isLive && !panel) ? _onHDragUpdate : null,
                    onHorizontalDragEnd: (app.gestures && !locked && !isLive && !panel) ? (_) => _onHDragEnd() : null,
                  ),
                ),

                // ---- spinner
                if (spinner)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                      child: SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary)),
                    ),
                  ),

                // ---- flash hint (volume, seek, channel name…)
                if (flashText != null)
                  Align(
                    alignment: const Alignment(0, -0.55),
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(22)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (flashIcon != null) ...[Icon(flashIcon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                            Flexible(child: Text(flashText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ---- error card
                if (error != null) Center(child: _errorCard(cs)),

                // ---- controls
                if (!locked) _controlsLayer(cs),

                // ---- locked indicator
                if (locked)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: SafeArea(
                      child: AnimatedOpacity(
                        opacity: controls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onLongPress: () {
                            setState(() => locked = false);
                            _show();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(24)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(app.t('unlockHint'), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ---- channel list panel
                if (panel) _zapPanel(cs),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _errorCard(ColorScheme cs) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xE6101218), borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB454), size: 40),
          const SizedBox(height: 10),
          Text(app.t('playFailed'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(error ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB8BECC), fontSize: 12.5)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(autofocus: true, onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: Text(app.t('retry'))),
              if (sources.length > 1)
                OutlinedButton(onPressed: _nextServer, child: Text(app.t('nextServer'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {double size = 44, String? tip, Color? color}) {
    return Tappable(
      radius: size,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Tooltip(
          message: tip ?? '',
          child: Icon(icon, color: onTap == null ? Colors.white38 : (color ?? Colors.white), size: size * 0.56),
        ),
      ),
    );
  }

  Widget _controlsLayer(ColorScheme cs) {
    final multi = widget.playlist.length > 1;
    final fav = app.isFav(ch);
    final res = _resLabel;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !controls || panel,
        child: AnimatedOpacity(
          opacity: (controls && !panel) ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              children: [
                // ---- top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Color(0x00000000)]),
                    ),
                    child: Row(
                      children: [
                        _iconBtn(Icons.arrow_back_rounded, () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 4),
                        Logo(url: ch.logo, size: 38, radius: 10, name: ch.name),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              if (ch.group.isNotEmpty || sources.length > 1)
                                Text(
                                  [if (ch.group.isNotEmpty) ch.group, if (sources.length > 1) sources[selected].name].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFC7CCD8), fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (res.isNotEmpty) _badge(res, cs.primary),
                        _iconBtn(
                          vol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          () {
                            if (vol > 0) {
                              _lastVol = vol;
                              player.setVolume(0);
                            } else {
                              player.setVolume(_lastVol > 0 ? _lastVol : 100);
                            }
                            setState(() {});
                            _show();
                          },
                        ),
                        _iconBtn(
                          fav ? Icons.star_rounded : Icons.star_border_rounded,
                          () {
                            app.toggleFav(ch);
                            setState(() {});
                            _show();
                          },
                          color: fav ? const Color(0xFFFFC83D) : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- centre controls
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (multi) _iconBtn(Icons.skip_previous_rounded, () { _zap(-1); _show(); }, size: 54),
                      if (!isLive) _iconBtn(Icons.replay_10_rounded, () { _seekBy(-app.seekSecs); _show(); }, size: 54),
                      const SizedBox(width: 8),
                      Tappable(
                        radius: 50,
                        onTap: _togglePlay,
                        child: Container(
                          width: 72,
                          height: 72,
                          color: cs.primary,
                          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44, color: cs.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isLive) _iconBtn(Icons.forward_10_rounded, () { _seekBy(app.seekSecs); _show(); }, size: 54),
                      if (multi) _iconBtn(Icons.skip_next_rounded, () { _zap(1); _show(); }, size: 54),
                    ],
                  ),
                ),

                // ---- bottom bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xDD000000)]),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isLive) _seekBar(cs),
                        Row(
                          children: [
                            if (isLive) _badge('● ${app.t('live')}', const Color(0xFFE5173F), filled: true),
                            const Spacer(),
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (sources.length > 1) _iconBtn(Icons.dns_rounded, _serverSheet, size: 42, tip: app.t('server')),
                                    _iconBtn(Icons.subtitles_rounded, _tracksSheet, size: 42, tip: app.t('tracks')),
                                    _iconBtn(Icons.aspect_ratio_rounded, _cycleFit, size: 42, tip: app.t('aspect')),
                                    _iconBtn(
                                      Icons.timer_rounded,
                                      _moreSheet,
                                      size: 42,
                                      tip: app.t('more'),
                                      color: sleepMin > 0 || rate != 1 ? cs.primary : Colors.white,
                                    ),
                                    _iconBtn(Icons.screen_rotation_rounded, _toggleOrientation, size: 42),
                                    _iconBtn(Icons.lock_outline_rounded, () => setState(() => locked = true), size: 42, tip: app.t('lock')),
                                    if (multi)
                                      _iconBtn(Icons.format_list_bulleted_rounded, () {
                                        setState(() => panel = true);
                                        _hide?.cancel();
                                      }, size: 42, tip: app.t('channelList')),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {bool filled = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: filled ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  String _fmt(Duration d) {
    final t = d.inSeconds;
    final h = t ~/ 3600, m = (t % 3600) ~/ 60, s = t % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _seekBar(ColorScheme cs) {
    return ListenableBuilder(
      listenable: Listenable.merge([position, bufferPos]),
      builder: (context, _) {
        final total = duration.inMilliseconds;
        final pos = position.value;
        final v = _dragValue ?? (total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0);
        final b = total > 0 ? (bufferPos.value.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
        final shown = _dragValue != null ? Duration(milliseconds: (_dragValue! * total).round()) : pos;
        return Row(
          children: [
            const SizedBox(width: 6),
            Text(_fmt(shown), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: cs.primary,
                  thumbColor: cs.primary,
                  secondaryActiveTrackColor: Colors.white38,
                  inactiveTrackColor: Colors.white24,
                ),
                child: Slider(
                  value: v,
                  secondaryTrackValue: b,
                  onChangeStart: (_) => _hide?.cancel(),
                  onChanged: (x) => setState(() => _dragValue = x),
                  onChangeEnd: (x) {
                    player.seek(Duration(milliseconds: (x * total).round()));
                    setState(() => _dragValue = null);
                    _scheduleHide();
                  },
                ),
              ),
            ),
            Text(_fmt(duration), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(width: 6),
          ],
        );
      },
    );
  }

  Widget _zapPanel(ColorScheme cs) {
    final list = widget.playlist;
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 320,
      child: Material(
        color: const Color(0xF2101218),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${app.t('channelList')} · ${list.length}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: _closePanel, icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _panelScroll,
                  itemExtent: 64,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final cur = i == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Tappable(
                        radius: 14,
                        autofocus: cur,
                        onTap: () {
                          _closePanel();
                          if (!cur) _loadChannel(i);
                        },
                        child: Container(
                          color: cur ? cs.primary.withValues(alpha: 0.22) : Colors.white10,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Logo(url: c.logo, size: 40, radius: 10, name: c.name),
                              const SizedBox(width: 10),
                              Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: cur ? FontWeight.w800 : FontWeight.w500))),
                              if (cur) Icon(Icons.equalizer_rounded, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
