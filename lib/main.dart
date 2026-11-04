import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'core/app_controller.dart';
import 'core/theme.dart';
import 'ui/channels_page.dart';
import 'ui/favorites_page.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final controller = await AppController.create();
  runApp(AppScope(controller: controller, child: const KobaniApp()));
}

class KobaniApp extends StatefulWidget {
  const KobaniApp({super.key});

  @override
  State<KobaniApp> createState() => _KobaniAppState();
}

class _KobaniAppState extends State<KobaniApp> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (!_started) {
      _started = true;
      // Load channels after the first frame so the UI shows instantly.
      WidgetsBinding.instance.addPostFrameCallback((_) => c.loadChannels());
    }
    final spec = kThemes[c.themeIdx];
    final theme = buildTheme(spec, Color(kAccents[c.accentIdx]));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KOBANI 4K',
      theme: theme,
      builder: (context, child) => Directionality(
        textDirection: c.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [spec.bgTop, spec.bgBottom],
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final wide = MediaQuery.of(context).size.width >= 840;

    final pages = <Widget>[
      HomePage(
        onOpenChannels: () => _go(1),
        onOpenGroup: (g) {
          c.setGroupFilter(g);
          _go(1);
        },
      ),
      const ChannelsPage(),
      const FavoritesPage(),
      const SettingsPage(),
    ];

    final dests = [
      (Icons.home_outlined, Icons.home_rounded, c.t('home')),
      (Icons.live_tv_outlined, Icons.live_tv_rounded, c.t('channels')),
      (Icons.star_border_rounded, Icons.star_rounded, c.t('favorites')),
      (Icons.settings_outlined, Icons.settings_rounded, c.t('settings')),
    ];

    final body = IndexedStack(index: _tab, children: pages);

    return Scaffold(
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in dests)
                      NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                  ],
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _go,
              destinations: [
                for (final d in dests)
                  NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }
}
