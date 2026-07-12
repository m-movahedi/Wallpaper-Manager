import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image_lib;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xml/xml.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    launchAtStartup.setup(
      appName: 'Wallpaper Manager',
      appPath: Platform.resolvedExecutable,
      packageName: 'com.mohammadmovahedi.wallpapermanager',
    );
  }
  runApp(const WallpaperApp());
}

enum _AppThemePreference { system, light, dark }

class WallpaperApp extends StatefulWidget {
  const WallpaperApp({super.key});

  @override
  State<WallpaperApp> createState() => _WallpaperAppState();
}

class _WallpaperAppState extends State<WallpaperApp> {
  _AppThemePreference themePreference = _AppThemePreference.system;
  bool minimizeToTray = false;
  bool runInBackground = false;
  bool runOnStartup = false;
  Color accentColor = const Color(0xff526b5a);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString('app_theme');
    if (!mounted) return;
    setState(() {
      themePreference = _AppThemePreference.values.firstWhere(
        (value) => value.name == savedTheme,
        orElse: () => _AppThemePreference.system,
      );
      minimizeToTray = false;
      runInBackground = false;
    });
    final tray = preferences.getBool('minimize_to_tray') ?? false;
    final background = preferences.getBool('run_in_background') ?? false;
    final savedAccent = preferences.getInt('accent_color');
    final startup = preferences.getBool('run_on_startup') ?? false;
    if (!mounted) return;
    setState(() {
      minimizeToTray = tray;
      runInBackground = background;
      if (savedAccent != null) accentColor = Color(savedAccent);
      runOnStartup = startup;
    });
  }

  Future<void> _setTheme(_AppThemePreference value) async {
    setState(() => themePreference = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_theme', value.name);
  }

  Future<void> _setMinimizeToTray(bool value) async {
    setState(() => minimizeToTray = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('minimize_to_tray', value);
  }

  Future<void> _setRunInBackground(bool value) async {
    setState(() => runInBackground = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('run_in_background', value);
  }

  Future<void> _setAccentColor(Color value) async {
    setState(() => accentColor = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('accent_color', value.toARGB32());
  }

  Future<void> _setRunOnStartup(bool value) async {
    if (value) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    if (!mounted) return;
    setState(() => runOnStartup = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('run_on_startup', value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wallpaper Manager',
    debugShowCheckedModeBanner: false,
    themeMode: switch (themePreference) {
      _AppThemePreference.system => ThemeMode.system,
      _AppThemePreference.light => ThemeMode.light,
      _AppThemePreference.dark => ThemeMode.dark,
    },
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    home: _AppShell(
      themePreference: themePreference,
      onThemeChanged: _setTheme,
      minimizeToTray: minimizeToTray,
      onMinimizeToTrayChanged: _setMinimizeToTray,
      runInBackground: runInBackground,
      onRunInBackgroundChanged: _setRunInBackground,
      accentColor: accentColor,
      onAccentColorChanged: _setAccentColor,
      runOnStartup: runOnStartup,
      onRunOnStartupChanged: _setRunOnStartup,
    ),
  );

  ThemeData _buildTheme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xfff4f1eb)
        : const Color(0xff111512),
    cardTheme: CardThemeData(
      color: brightness == Brightness.light
          ? const Color(0xd9ffffff)
          : const Color(0xff202722),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: Color(0x1a203027)),
      ),
    ),
    useMaterial3: true,
  );
}

enum AppDestination {
  library('Library', Icons.grid_view_rounded),
  sources('Sources', Icons.dynamic_feed_rounded),
  nowPlaying('Now playing', Icons.wallpaper_rounded),
  schedules('Schedules', Icons.schedule_rounded),
  favorites('Favorites', Icons.favorite_outline_rounded),
  downloads('Downloads', Icons.download_outlined),
  devices('Devices', Icons.devices_rounded),
  settings('Settings', Icons.tune_rounded);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.themePreference,
    required this.onThemeChanged,
    required this.minimizeToTray,
    required this.onMinimizeToTrayChanged,
    required this.runInBackground,
    required this.onRunInBackgroundChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    required this.runOnStartup,
    required this.onRunOnStartupChanged,
  });
  final _AppThemePreference themePreference;
  final ValueChanged<_AppThemePreference> onThemeChanged;
  final bool minimizeToTray;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final bool runInBackground;
  final ValueChanged<bool> onRunInBackgroundChanged;
  final Color accentColor;
  final ValueChanged<Color> onAccentColorChanged;
  final bool runOnStartup;
  final ValueChanged<bool> onRunOnStartupChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell>
    with WindowListener, TrayListener {
  var selected = AppDestination.library;
  final List<_AddedSource> sources = [];
  final Set<String> favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadLibraryState();
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _configureDesktopBackgroundBehavior();
    }
  }

  Future<void> _loadLibraryState() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedSources = preferences.getString('library_sources');
    final savedFavorites =
        preferences.getStringList('favorite_media_ids') ?? const [];
    final restored = <_AddedSource>[];
    if (encodedSources != null) {
      try {
        final decoded = jsonDecode(encodedSources) as List<dynamic>;
        restored.addAll(
          decoded.whereType<Map<String, dynamic>>().map(
            (item) => _AddedSource.fromJson(item.cast<String, Object?>()),
          ),
        );
      } on Object {
        // Keep the app usable if a previous state file is malformed.
      }
    }
    if (!mounted) return;
    setState(() {
      sources
        ..clear()
        ..addAll(restored);
      favoriteIds
        ..clear()
        ..addAll(savedFavorites);
    });
  }

  Future<void> _saveLibraryState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'library_sources',
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
    await preferences.setStringList('favorite_media_ids', favoriteIds.toList());
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimizeToTray != widget.minimizeToTray) {
      _configureDesktopBackgroundBehavior();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _configureDesktopBackgroundBehavior() async {
    await windowManager.setPreventClose(widget.minimizeToTray);
    if (!widget.minimizeToTray) {
      await trayManager.destroy();
      return;
    }
    final trayAsset = Platform.isWindows
        ? 'assets/icons/tray_icon.ico'
        : 'assets/icons/tray_icon.png';
    final trayData = await rootBundle.load(trayAsset);
    final trayFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}wallpaper-manager-tray${Platform.isWindows ? '.ico' : '.png'}',
    );
    await trayFile.writeAsBytes(
      trayData.buffer.asUint8List(
        trayData.offsetInBytes,
        trayData.lengthInBytes,
      ),
      flush: true,
    );
    await trayManager.setIcon(trayFile.path);
    await trayManager.setToolTip('Wallpaper Manager');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: 'Open'),
          MenuItem(key: 'settings', label: 'Settings'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  @override
  Future<void> onWindowClose() async {
    if (widget.minimizeToTray) {
      await windowManager.hide();
    }
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'open') {
      await onTrayIconMouseDown();
    } else if (menuItem.key == 'settings') {
      setState(() => selected = AppDestination.settings);
      await onTrayIconMouseDown();
    } else if (menuItem.key == 'quit') {
      await _quitApplication();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final content = IndexedStack(
        index: selected == AppDestination.nowPlaying ? 1 : 0,
        children: [
          _LibraryPage(
            destination: selected == AppDestination.nowPlaying
                ? AppDestination.library
                : selected,
            sources: sources,
            onAddSource: _addSource,
            onUpdateSource: _updateSource,
            onRemoveSource: _removeSource,
            onMergeSource: _mergeSource,
            favoriteIds: favoriteIds,
            onToggleFavorite: _toggleFavorite,
            themePreference: widget.themePreference,
            onThemeChanged: widget.onThemeChanged,
            minimizeToTray: widget.minimizeToTray,
            onMinimizeToTrayChanged: widget.onMinimizeToTrayChanged,
            runInBackground: widget.runInBackground,
            onRunInBackgroundChanged: widget.onRunInBackgroundChanged,
            accentColor: widget.accentColor,
            onAccentColorChanged: widget.onAccentColorChanged,
            runOnStartup: widget.runOnStartup,
            onRunOnStartupChanged: widget.onRunOnStartupChanged,
          ),
          _NowPlayingPage(sources: sources, favoriteIds: favoriteIds),
        ],
      );
      if (!desktop) {
        return Scaffold(
          appBar: AppBar(title: Text(selected.label)),
          drawer: Drawer(
            child: SafeArea(
              child: _Navigation(selected: selected, onSelect: _select),
            ),
          ),
          body: content,
        );
      }
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: _Navigation(selected: selected, onSelect: _select),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    },
  );

  void _select(AppDestination value) => setState(() => selected = value);

  void _addSource(_AddedSource source) {
    setState(() => sources.add(source));
    unawaited(_saveLibraryState());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${source.name} added to your sources.')),
    );
  }

  void _updateSource(_AddedSource current, _AddedSource updated) {
    final index = sources.indexOf(current);
    if (index < 0) return;
    setState(() => sources[index] = updated);
    unawaited(_saveLibraryState());
  }

  void _removeSource(_AddedSource source) {
    setState(() => sources.remove(source));
    unawaited(_saveLibraryState());
  }

  void _mergeSource(_AddedSource source, _AddedSource target) {
    final targetIndex = sources.indexOf(target);
    if (targetIndex < 0 || source == target) return;
    final mergedMedia = {...target.mediaPaths, ...source.mediaPaths}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final mergedRemoteMedia = {
      ...target.mediaUrls,
      ...source.mediaUrls,
    }.toList()..sort((a, b) => a.toString().compareTo(b.toString()));
    final extraEndpoints = <Uri>[
      ...target.additionalEndpoints,
      if (source.endpoint != null) source.endpoint!,
      ...source.additionalEndpoints,
    ];
    final extraDirectories = <String>[
      ...target.additionalDirectoryPaths,
      if (source.directoryPath != null) source.directoryPath!,
      ...source.additionalDirectoryPaths,
    ];
    setState(() {
      sources[targetIndex] = target.copyWith(
        mediaPaths: mergedMedia,
        mediaUrls: mergedRemoteMedia,
        additionalEndpoints: extraEndpoints,
        additionalDirectoryPaths: extraDirectories,
        mergedSourceCount: target.mergedSourceCount + source.mergedSourceCount,
      );
      sources.remove(source);
    });
    unawaited(_saveLibraryState());
  }

  void _toggleFavorite(_MediaItem item) {
    setState(() {
      if (!favoriteIds.add(item.id)) favoriteIds.remove(item.id);
    });
    unawaited(_saveLibraryState());
  }
}

typedef _UpdateSource =
    void Function(_AddedSource current, _AddedSource updated);
typedef _MergeSource = void Function(_AddedSource source, _AddedSource target);

enum _PlaybackOrder { ascending, descending, random }

enum _WallpaperDisplayMode { fill, fit, stretch, center, tile, span }

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.themePreference,
    required this.onThemeChanged,
    required this.minimizeToTray,
    required this.onMinimizeToTrayChanged,
    required this.runInBackground,
    required this.onRunInBackgroundChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    required this.runOnStartup,
    required this.onRunOnStartupChanged,
  });
  final _AppThemePreference themePreference;
  final ValueChanged<_AppThemePreference> onThemeChanged;
  final bool minimizeToTray;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final bool runInBackground;
  final ValueChanged<bool> onRunInBackgroundChanged;
  final Color accentColor;
  final ValueChanged<Color> onAccentColorChanged;
  final bool runOnStartup;
  final ValueChanged<bool> onRunOnStartupChanged;

  @override
  Widget build(BuildContext context) {
    final desktop = Platform.isWindows || Platform.isMacOS;
    final mobile = Platform.isIOS || Platform.isAndroid;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                SegmentedButton<_AppThemePreference>(
                  segments: const [
                    ButtonSegment(
                      value: _AppThemePreference.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: _AppThemePreference.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: _AppThemePreference.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themePreference},
                  onSelectionChanged: (values) => onThemeChanged(values.first),
                ),
                const SizedBox(height: 22),
                Text(
                  'Accent color',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _accentColors)
                      Tooltip(
                        message: _accentColorName(color),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onAccentColorChanged(color),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    color.toARGB32() == accentColor.toARGB32()
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: color.toARGB32() == accentColor.toARGB32()
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: runOnStartup,
                onChanged: desktop ? onRunOnStartupChanged : null,
                secondary: const Icon(Icons.power_settings_new_rounded),
                title: const Text('Run on startup'),
                subtitle: Text(
                  desktop
                      ? 'Start Wallpaper Manager when you sign in.'
                      : 'Available on Windows and macOS.',
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: minimizeToTray,
                onChanged: desktop ? onMinimizeToTrayChanged : null,
                secondary: const Icon(Icons.move_to_inbox_rounded),
                title: const Text('Minimize to tray'),
                subtitle: Text(
                  desktop
                      ? 'Closing the window keeps Wallpaper available from the system tray.'
                      : 'Available on Windows and macOS.',
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: runInBackground,
                onChanged: mobile ? onRunInBackgroundChanged : null,
                secondary: const Icon(Icons.sync_rounded),
                title: const Text('Run in background'),
                subtitle: Text(
                  mobile
                      ? 'Allow scheduled wallpaper work when the app is not open.'
                      : 'Available on iOS and Android; subject to operating-system limits.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://m-movahedi.com'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(
              Icons.favorite_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text('Developed with ❤️ by Mohammad Movahedi'),
          ),
        ),
        if (desktop) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _quitApplication,
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Quit Wallpaper Manager'),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _quitApplication() async {
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.close();
  } else {
    await SystemNavigator.pop();
  }
}

const _accentColors = [
  Color(0xff526b5a),
  Color(0xff3f51b5),
  Color(0xff6750a4),
  Color(0xff9c27b0),
  Color(0xffd94f70),
  Color(0xffe76f51),
  Color(0xff00796b),
  Color(0xff1976d2),
];

String _accentColorName(Color color) => switch (color.toARGB32()) {
  0xff526b5a => 'Sage',
  0xff3f51b5 => 'Indigo',
  0xff6750a4 => 'Violet',
  0xff9c27b0 => 'Purple',
  0xffd94f70 => 'Rose',
  0xffe76f51 => 'Coral',
  0xff00796b => 'Teal',
  _ => 'Blue',
};

class _NowPlayingPage extends StatefulWidget {
  const _NowPlayingPage({required this.sources, required this.favoriteIds});
  final List<_AddedSource> sources;
  final Set<String> favoriteIds;

  @override
  State<_NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<_NowPlayingPage> {
  final Set<String> selectedSourceIds = {};
  bool includeFavorites = false;
  _PlaybackOrder order = _PlaybackOrder.ascending;
  _WallpaperDisplayMode displayMode = _WallpaperDisplayMode.fill;
  int currentIndex = 0;
  bool applying = false;
  bool isPlaying = true;
  Duration changeInterval = const Duration(minutes: 15);
  Timer? playbackTimer;

  @override
  void initState() {
    super.initState();
    _loadPlaybackState();
    _restartPlaybackTimer();
  }

  Future<void> _loadPlaybackState() async {
    final preferences = await SharedPreferences.getInstance();
    final sourceIds =
        preferences.getStringList('playback_source_ids') ?? const [];
    final savedOrder = preferences.getString('playback_order');
    final savedDisplay = preferences.getString('playback_display_mode');
    final savedSeconds = preferences.getInt('playback_change_interval_seconds');
    final savedPlaying = preferences.getBool('playback_is_playing');
    if (!mounted) return;
    setState(() {
      selectedSourceIds
        ..clear()
        ..addAll(sourceIds);
      includeFavorites =
          preferences.getBool('playback_include_favorites') ?? false;
      order = _PlaybackOrder.values.firstWhere(
        (value) => value.name == savedOrder,
        orElse: () => _PlaybackOrder.ascending,
      );
      displayMode = _WallpaperDisplayMode.values.firstWhere(
        (value) => value.name == savedDisplay,
        orElse: () => _WallpaperDisplayMode.fill,
      );
      if (savedSeconds != null) {
        changeInterval = Duration(seconds: savedSeconds);
      }
      if (savedPlaying != null) {
        isPlaying = savedPlaying;
      }
    });
    _restartPlaybackTimer();
  }

  Future<void> _savePlaybackState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'playback_source_ids',
      selectedSourceIds.toList(),
    );
    await preferences.setBool('playback_include_favorites', includeFavorites);
    await preferences.setString('playback_order', order.name);
    await preferences.setString('playback_display_mode', displayMode.name);
    await preferences.setInt(
      'playback_change_interval_seconds',
      changeInterval.inSeconds,
    );
    await preferences.setBool('playback_is_playing', isPlaying);
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    super.dispose();
  }

  void _restartPlaybackTimer() {
    playbackTimer?.cancel();
    if (!isPlaying) return;
    playbackTimer = Timer.periodic(changeInterval, (_) => _advanceAndApply());
  }

  void _togglePlayback() {
    setState(() => isPlaying = !isPlaying);
    _restartPlaybackTimer();
    unawaited(_savePlaybackState());
  }

  Future<void> _advanceAndApply() async {
    final playlist = items;
    if (!mounted || playlist.length < 2 || applying) return;
    final nextIndex = (currentIndex + 1) % playlist.length;
    setState(() => currentIndex = nextIndex);
    await _apply(playlist[nextIndex], quiet: true);
  }

  List<_MediaItem> get items {
    final unique = <String, _MediaItem>{};
    for (final source in widget.sources.where(
      (source) => selectedSourceIds.contains(source.id),
    )) {
      for (final item in source.mediaItems) {
        unique[item.id] = item;
      }
    }
    if (includeFavorites) {
      for (final item in _favoriteItems(widget.sources, widget.favoriteIds)) {
        unique[item.id] = item;
      }
    }
    final result = unique.values.where((item) => !item.isVideo).toList();
    result.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    if (order == _PlaybackOrder.descending) return result.reversed.toList();
    if (order == _PlaybackOrder.random) {
      result.shuffle(Random(currentIndex + result.length));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final playlist = items;
    if (currentIndex >= playlist.length) currentIndex = 0;
    final current = playlist.isEmpty ? null : playlist[currentIndex];
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Now playing',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: current == null
                  ? const Center(
                      child: Text('Choose one or more libraries below.'),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: SizedBox.expand(
                        key: ValueKey(current.id),
                        child: _MediaVisual(
                          item: current,
                          fit: _boxFit(displayMode),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LibraryPoolDropdown(
                        sources: widget.sources,
                        selectedSourceIds: selectedSourceIds,
                        includeFavorites: includeFavorites,
                        onFavoritesChanged: (value) => setState(() {
                          includeFavorites = value;
                          currentIndex = 0;
                          unawaited(_savePlaybackState());
                        }),
                        onSourceChanged: (source, selected) => setState(() {
                          selected
                              ? selectedSourceIds.add(source.id)
                              : selectedSourceIds.remove(source.id);
                          currentIndex = 0;
                          unawaited(_savePlaybackState());
                        }),
                      ),
                      _CompactDropdown<_PlaybackOrder>(
                        label: 'Order',
                        value: order,
                        values: _PlaybackOrder.values,
                        labelFor: (value) =>
                            value.name[0].toUpperCase() +
                            value.name.substring(1),
                        onChanged: (value) => setState(() {
                          order = value;
                          currentIndex = 0;
                          unawaited(_savePlaybackState());
                        }),
                      ),
                      _CompactDropdown<_WallpaperDisplayMode>(
                        label: 'Display',
                        value: displayMode,
                        values: _WallpaperDisplayMode.values,
                        labelFor: _modeLabel,
                        onChanged: (value) => setState(() {
                          displayMode = value;
                          unawaited(_savePlaybackState());
                        }),
                      ),
                      _CompactDropdown<Duration>(
                        label: 'Change background every',
                        value: changeInterval,
                        values: _playbackIntervals,
                        labelFor: _playbackIntervalLabel,
                        onChanged: (value) {
                          setState(() => changeInterval = value);
                          _restartPlaybackTimer();
                          unawaited(_savePlaybackState());
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Previous image',
                          onPressed: playlist.length < 2
                              ? null
                              : () => setState(
                                  () => currentIndex =
                                      (currentIndex - 1 + playlist.length) %
                                      playlist.length,
                                ),
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        IconButton.filled(
                          tooltip: isPlaying
                              ? 'Pause automatic changes'
                              : 'Play automatic changes',
                          onPressed: current == null ? null : _togglePlayback,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next image',
                          onPressed: playlist.length < 2
                              ? null
                              : () => setState(
                                  () => currentIndex =
                                      (currentIndex + 1) % playlist.length,
                                ),
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: applying || current == null
                              ? null
                              : () => _apply(current),
                          icon: const Icon(Icons.wallpaper_rounded),
                          label: Text(
                            applying ? 'Applying…' : 'Apply background',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(_MediaItem item, {bool quiet = false}) async {
    setState(() => applying = true);
    try {
      await _WindowsWallpaperService.apply(item, displayMode);
      if (!mounted) return;
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Desktop background updated.')),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not apply background: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }
}

String _modeLabel(_WallpaperDisplayMode mode) => switch (mode) {
  _WallpaperDisplayMode.fill => 'Fill',
  _WallpaperDisplayMode.fit => 'Fit',
  _WallpaperDisplayMode.stretch => 'Stretch',
  _WallpaperDisplayMode.center => 'Center',
  _WallpaperDisplayMode.tile => 'Tile',
  _WallpaperDisplayMode.span => 'Span displays',
};

BoxFit _boxFit(_WallpaperDisplayMode mode) => switch (mode) {
  _WallpaperDisplayMode.fill || _WallpaperDisplayMode.span => BoxFit.cover,
  _WallpaperDisplayMode.fit || _WallpaperDisplayMode.center => BoxFit.contain,
  _WallpaperDisplayMode.stretch || _WallpaperDisplayMode.tile => BoxFit.fill,
};

class _WindowsWallpaperService {
  static const _channel = MethodChannel('wallpaper/native');

  static Future<void> apply(_MediaItem item, _WallpaperDisplayMode mode) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Background application is currently implemented for Windows.',
      );
    }
    var path = item.localPath;
    if (path == null) {
      final client = http.Client();
      final request = http.Request('GET', item.remoteUri!);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close();
        throw http.ClientException(
          'Image returned HTTP ${response.statusCode}.',
          item.remoteUri,
        );
      }
      final extension = _safeImageExtension(item.remoteUri!.path);
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}wallpaper-download$extension',
      );
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          received += chunk.length;
          if (received > 250 * 1024 * 1024) {
            throw const FormatException(
              'Image is larger than the 250 MB safety limit.',
            );
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
        client.close();
      }
      path = file.path;
    }
    final sourceFile = File(path);
    if (await sourceFile.length() > 50 * 1024 * 1024) {
      final optimizedPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}wallpaper-current.jpg';
      path = await Isolate.run(() => _optimizeWallpaper(path!, optimizedPath));
    }
    await _channel.invokeMethod<void>('setWallpaper', {
      'path': path,
      'mode': mode.name,
    });
  }
}

Future<String> _optimizeWallpaper(String sourcePath, String outputPath) async {
  var decoded = await image_lib.decodeImageFile(sourcePath);
  if (decoded == null) {
    throw const FormatException('The image format could not be decoded.');
  }
  decoded = image_lib.bakeOrientation(decoded);
  final scale = min(1.0, min(7680 / decoded.width, 4320 / decoded.height));
  if (scale < 1) {
    decoded = image_lib.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: image_lib.Interpolation.cubic,
    );
  }
  await File(
    outputPath,
  ).writeAsBytes(image_lib.encodeJpg(decoded, quality: 88), flush: true);
  return outputPath;
}

String _safeImageExtension(String path) {
  final match = RegExp(
    r'\.(?:jpe?g|png|bmp|webp)$',
    caseSensitive: false,
  ).firstMatch(path);
  return match?.group(0)?.toLowerCase() ?? '.jpg';
}

const _playbackIntervals = [
  Duration(seconds: 10),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(hours: 1),
];

String _playbackIntervalLabel(Duration value) {
  if (value.inSeconds < 60) return '${value.inSeconds}s';
  if (value.inMinutes < 60) return '${value.inMinutes}m';
  return '${value.inHours}h';
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<T>(
    value: value,
    underline: const SizedBox.shrink(),
    borderRadius: BorderRadius.circular(14),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text('$label: ${labelFor(item)}')),
    ],
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );
}

class _LibraryPoolDropdown extends StatelessWidget {
  const _LibraryPoolDropdown({
    required this.sources,
    required this.selectedSourceIds,
    required this.includeFavorites,
    required this.onFavoritesChanged,
    required this.onSourceChanged,
  });
  final List<_AddedSource> sources;
  final Set<String> selectedSourceIds;
  final bool includeFavorites;
  final ValueChanged<bool> onFavoritesChanged;
  final void Function(_AddedSource source, bool selected) onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final count = selectedSourceIds.length + (includeFavorites ? 1 : 0);
    return PopupMenuButton<Object>(
      tooltip: 'Choose libraries',
      onSelected: (value) {
        if (value == 'favorites') {
          onFavoritesChanged(!includeFavorites);
        } else if (value is _AddedSource) {
          onSourceChanged(value, !selectedSourceIds.contains(value.id));
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'favorites',
          checked: includeFavorites,
          child: const Text('My Favorites'),
        ),
        for (final source in sources)
          CheckedPopupMenuItem(
            value: source,
            checked: selectedSourceIds.contains(source.id),
            child: Text(source.name),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_add_check_rounded, size: 20),
              const SizedBox(width: 8),
              Text(count == 0 ? 'Choose libraries' : '$count libraries'),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.selected, required this.onSelect});
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Text(
            'WALLPAPER',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        for (final item in AppDestination.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              selected: item == selected,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () => onSelect(item),
            ),
          ),
        const Spacer(),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Local-first\nSign in only when you want sync.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.destination,
    required this.sources,
    required this.onAddSource,
    required this.onUpdateSource,
    required this.onRemoveSource,
    required this.onMergeSource,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.themePreference,
    required this.onThemeChanged,
    required this.minimizeToTray,
    required this.onMinimizeToTrayChanged,
    required this.runInBackground,
    required this.onRunInBackgroundChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    required this.runOnStartup,
    required this.onRunOnStartupChanged,
  });
  final AppDestination destination;
  final List<_AddedSource> sources;
  final ValueChanged<_AddedSource> onAddSource;
  final _UpdateSource onUpdateSource;
  final ValueChanged<_AddedSource> onRemoveSource;
  final _MergeSource onMergeSource;
  final Set<String> favoriteIds;
  final ValueChanged<_MediaItem> onToggleFavorite;
  final _AppThemePreference themePreference;
  final ValueChanged<_AppThemePreference> onThemeChanged;
  final bool minimizeToTray;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final bool runInBackground;
  final ValueChanged<bool> onRunInBackgroundChanged;
  final Color accentColor;
  final ValueChanged<Color> onAccentColorChanged;
  final bool runOnStartup;
  final ValueChanged<bool> onRunOnStartupChanged;

  @override
  Widget build(BuildContext context) {
    if (destination == AppDestination.sources) {
      return _SourcesPage(
        sources: sources,
        onAddSource: onAddSource,
        onUpdateSource: onUpdateSource,
        onRemoveSource: onRemoveSource,
        onMergeSource: onMergeSource,
      );
    }
    if (destination != AppDestination.library) {
      if (destination == AppDestination.nowPlaying) {
        return _NowPlayingPage(sources: sources, favoriteIds: favoriteIds);
      }
      if (destination == AppDestination.settings) {
        return _SettingsPage(
          themePreference: themePreference,
          onThemeChanged: onThemeChanged,
          minimizeToTray: minimizeToTray,
          onMinimizeToTrayChanged: onMinimizeToTrayChanged,
          runInBackground: runInBackground,
          onRunInBackgroundChanged: onRunInBackgroundChanged,
          accentColor: accentColor,
          onAccentColorChanged: onAccentColorChanged,
          runOnStartup: runOnStartup,
          onRunOnStartupChanged: onRunOnStartupChanged,
        );
      }
      return Center(
        child: Text('${destination.label} is ready for its feature module.'),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your space',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('One quiet place for every screen.'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddSourceDialog(context, onAddSource),
                  icon: const Icon(Icons.add),
                  label: const Text('Add source'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 240,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: sources.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final items = _favoriteItems(sources, favoriteIds);
                return _PoolCollectionCard(
                  name: 'My Favorites',
                  icon: Icons.favorite_rounded,
                  items: items,
                  onOpen: () => _openCollection(context, 'My Favorites', items),
                );
              }
              final source = sources[index - 1];
              return _CollectionCard(
                source: source,
                onOpen: () =>
                    _openCollection(context, source.name, source.mediaItems),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openCollection(
    BuildContext context,
    String name,
    List<_MediaItem> items,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CollectionPage(
          name: name,
          items: items,
          favoriteIds: favoriteIds,
          onToggleFavorite: onToggleFavorite,
        ),
      ),
    );
  }
}

enum _SourceType {
  rss(
    'RSS or Atom feed',
    Icons.rss_feed_rounded,
    'Images and videos from a secure feed URL',
  ),
  json(
    'JSON feed',
    Icons.data_object_rounded,
    'A documented JSON endpoint containing media URLs',
  ),
  googlePhotos(
    'Google Photos',
    Icons.photo_library_outlined,
    'Photos you explicitly select with Google',
  ),
  localAlbum(
    'Local album',
    Icons.folder_outlined,
    'A folder that stays only on this device',
  );

  const _SourceType(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class _AddedSource {
  _AddedSource({
    String? id,
    required this.name,
    required this.type,
    this.endpoint,
    this.directoryPath,
    this.mediaPaths = const [],
    this.mediaUrls = const [],
    this.additionalEndpoints = const [],
    this.additionalDirectoryPaths = const [],
    this.mergedSourceCount = 1,
    this.refreshInterval = const Duration(hours: 24),
  }) : id =
           id ??
           '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  final String id;
  final String name;
  final _SourceType type;
  final Uri? endpoint;
  final String? directoryPath;
  final List<String> mediaPaths;
  final List<Uri> mediaUrls;
  final List<Uri> additionalEndpoints;
  final List<String> additionalDirectoryPaths;
  final int mergedSourceCount;
  final Duration refreshInterval;

  int get itemCount => mediaPaths.length + mediaUrls.length;
  List<_MediaItem> get mediaItems => [
    for (final path in mediaPaths)
      _MediaItem(localPath: path, sourceName: name),
    for (final uri in mediaUrls) _MediaItem(remoteUri: uri, sourceName: name),
  ];

  _AddedSource copyWith({
    String? name,
    Uri? endpoint,
    bool clearEndpoint = false,
    String? directoryPath,
    List<String>? mediaPaths,
    List<Uri>? mediaUrls,
    List<Uri>? additionalEndpoints,
    List<String>? additionalDirectoryPaths,
    int? mergedSourceCount,
    Duration? refreshInterval,
  }) => _AddedSource(
    id: id,
    name: name ?? this.name,
    type: type,
    endpoint: clearEndpoint ? null : endpoint ?? this.endpoint,
    directoryPath: directoryPath ?? this.directoryPath,
    mediaPaths: mediaPaths ?? this.mediaPaths,
    mediaUrls: mediaUrls ?? this.mediaUrls,
    additionalEndpoints: additionalEndpoints ?? this.additionalEndpoints,
    additionalDirectoryPaths:
        additionalDirectoryPaths ?? this.additionalDirectoryPaths,
    mergedSourceCount: mergedSourceCount ?? this.mergedSourceCount,
    refreshInterval: refreshInterval ?? this.refreshInterval,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'endpoint': endpoint?.toString(),
    'directoryPath': directoryPath,
    'mediaPaths': mediaPaths,
    'mediaUrls': mediaUrls.map((uri) => uri.toString()).toList(),
    'additionalEndpoints': additionalEndpoints
        .map((uri) => uri.toString())
        .toList(),
    'additionalDirectoryPaths': additionalDirectoryPaths,
    'mergedSourceCount': mergedSourceCount,
    'refreshIntervalSeconds': refreshInterval.inSeconds,
  };

  factory _AddedSource.fromJson(Map<String, Object?> json) => _AddedSource(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Untitled source',
    type: _SourceType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => _SourceType.localAlbum,
    ),
    endpoint: _optionalUri(json['endpoint']),
    directoryPath: json['directoryPath'] as String?,
    mediaPaths: (json['mediaPaths'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    mediaUrls: (json['mediaUrls'] as List? ?? const [])
        .whereType<String>()
        .map(Uri.parse)
        .toList(),
    additionalEndpoints: (json['additionalEndpoints'] as List? ?? const [])
        .whereType<String>()
        .map(Uri.parse)
        .toList(),
    additionalDirectoryPaths:
        (json['additionalDirectoryPaths'] as List? ?? const [])
            .whereType<String>()
            .toList(),
    mergedSourceCount: json['mergedSourceCount'] as int? ?? 1,
    refreshInterval: Duration(
      seconds: json['refreshIntervalSeconds'] as int? ?? 86400,
    ),
  );
}

Uri? _optionalUri(Object? value) =>
    value is String && value.isNotEmpty ? Uri.tryParse(value) : null;

class _MediaItem {
  const _MediaItem({this.localPath, this.remoteUri, required this.sourceName})
    : assert(localPath != null || remoteUri != null);

  final String? localPath;
  final Uri? remoteUri;
  final String sourceName;

  String get id => localPath ?? remoteUri.toString();
  String get displayName {
    final value = localPath ?? remoteUri!.path;
    final separator = localPath == null ? '/' : Platform.pathSeparator;
    final name = value.split(separator).last;
    return name.isEmpty ? sourceName : Uri.decodeComponent(name);
  }

  bool get isVideo => _isVideoPath(id);
}

List<_MediaItem> _favoriteItems(
  List<_AddedSource> sources,
  Set<String> favoriteIds,
) => sources
    .expand((source) => source.mediaItems)
    .where((item) => favoriteIds.contains(item.id))
    .toList(growable: false);

Future<void> _showAddSourceDialog(
  BuildContext context,
  ValueChanged<_AddedSource> onAdded,
) async {
  final source = await showDialog<_AddedSource>(
    context: context,
    builder: (context) => const _AddSourceDialog(),
  );
  if (source != null) onAdded(source);
}

class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog();

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  _SourceType? selectedType;
  bool adding = false;
  Duration refreshInterval = const Duration(hours: 24);

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsUrl =
        selectedType == _SourceType.rss || selectedType == _SourceType.json;
    return AlertDialog(
      title: Text(selectedType == null ? 'Add a source' : selectedType!.label),
      content: SizedBox(
        width: 520,
        child: selectedType == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in _SourceType.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0x1a203027)),
                        ),
                        leading: Icon(type.icon),
                        title: Text(type.label),
                        subtitle: Text(type.description),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() {
                          selectedType = type;
                          nameController.text = type.label;
                        }),
                      ),
                    ),
                ],
              )
            : Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Source name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name.'
                          : null,
                    ),
                    if (needsUrl) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'HTTPS feed URL',
                          hintText: 'https://example.com/feed.xml',
                        ),
                        validator: _validateFeedUrl,
                      ),
                      if (selectedType == _SourceType.rss) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Duration>(
                          initialValue: refreshInterval,
                          decoration: const InputDecoration(
                            labelText: 'Refresh every',
                          ),
                          items: _refreshIntervals
                              .map(
                                (interval) => DropdownMenuItem(
                                  value: interval,
                                  child: Text(_durationLabel(interval)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => refreshInterval =
                                value ?? const Duration(hours: 24),
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        selectedType == _SourceType.googlePhotos
                            ? 'Google authorization and photo selection will open after this source is created.'
                            : 'Choose Add source to select a folder. Supported images and videos are scanned recursively and remain on this device.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (selectedType != null)
          TextButton(
            onPressed: () => setState(() => selectedType = null),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (selectedType != null)
          FilledButton(
            onPressed: adding ? null : _submit,
            child: Text(adding ? 'Scanning…' : 'Add source'),
          ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (selectedType == _SourceType.localAlbum) {
      final directoryPath = await getDirectoryPath(
        confirmButtonText: 'Add album',
      );
      if (directoryPath == null || !mounted) return;
      setState(() => adding = true);
      try {
        final mediaPaths = await _scanMediaDirectory(directoryPath);
        if (!mounted) return;
        Navigator.pop(
          context,
          _AddedSource(
            name: nameController.text.trim(),
            type: selectedType!,
            directoryPath: directoryPath,
            mediaPaths: mediaPaths,
          ),
        );
      } on FileSystemException catch (error) {
        if (!mounted) return;
        setState(() => adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read that folder: ${error.message}'),
          ),
        );
      }
      return;
    }
    final endpoint = urlController.text.trim().isEmpty
        ? null
        : Uri.parse(urlController.text.trim());
    if (selectedType == _SourceType.rss && endpoint != null) {
      setState(() => adding = true);
      try {
        final mediaUrls = await _fetchFeedMedia(endpoint);
        if (!mounted) return;
        Navigator.pop(
          context,
          _AddedSource(
            name: nameController.text.trim(),
            type: selectedType!,
            endpoint: endpoint,
            mediaUrls: mediaUrls,
            refreshInterval: refreshInterval,
          ),
        );
      } on FormatException catch (error) {
        if (!mounted) return;
        setState(() => adding = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } on http.ClientException catch (error) {
        if (!mounted) return;
        setState(() => adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load feed: ${error.message}')),
        );
      }
      return;
    }
    Navigator.pop(
      context,
      _AddedSource(
        name: nameController.text.trim(),
        type: selectedType!,
        endpoint: endpoint,
      ),
    );
  }
}

Future<List<Uri>> _fetchFeedMedia(Uri endpoint) async {
  final response = await http
      .get(
        endpoint,
        headers: const {
          'Accept':
              'application/rss+xml, application/atom+xml, application/xml, text/xml',
        },
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Feed returned HTTP ${response.statusCode}.',
      endpoint,
    );
  }
  if (response.bodyBytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Feed is larger than the 5 MB limit.');
  }

  final document = XmlDocument.parse(response.body);
  final urls = <Uri>{};
  for (final element in document.descendants.whereType<XmlElement>()) {
    final localName = element.name.local.toLowerCase();
    final type = element.getAttribute('type')?.toLowerCase();
    final candidate =
        element.getAttribute('url') ?? element.getAttribute('href');
    if (candidate != null &&
        (localName == 'enclosure' ||
            localName == 'content' ||
            localName == 'thumbnail') &&
        (type == null ||
            type.startsWith('image/') ||
            type.startsWith('video/'))) {
      final uri = endpoint.resolve(candidate.trim());
      if (uri.scheme == 'https') urls.add(uri);
    }

    if (localName == 'description' ||
        localName == 'encoded' ||
        localName == 'summary') {
      for (final match in RegExp(
        '''<(?:img|source)[^>]+(?:src|href)=["']([^"']+)["']''',
        caseSensitive: false,
      ).allMatches(element.innerText)) {
        final value = match.group(1);
        if (value == null) continue;
        final uri = endpoint.resolve(value.trim());
        if (uri.scheme == 'https') urls.add(uri);
      }
    }
    if (urls.length >= 200) break;
  }
  if (urls.isEmpty) {
    throw const FormatException(
      'The feed loaded, but it did not contain image or video enclosures.',
    );
  }
  return urls.toList(growable: false);
}

const _supportedMediaExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
  '.mp4',
  '.mov',
  '.m4v',
  '.webm',
};

Future<List<String>> _scanMediaDirectory(String directoryPath) async {
  final paths = <String>[];
  await for (final entity in Directory(
    directoryPath,
  ).list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final lowerPath = entity.path.toLowerCase();
    if (_supportedMediaExtensions.any(lowerPath.endsWith)) {
      paths.add(entity.path);
    }
    if (paths.length >= 2000) break;
  }
  paths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return paths;
}

bool _isVideoPath(String path) {
  final lowerPath = path.toLowerCase();
  return const {'.mp4', '.mov', '.m4v', '.webm'}.any(lowerPath.endsWith);
}

String? _validateFeedUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Enter a valid HTTPS URL.';
  }
  return null;
}

const _refreshIntervals = [
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(hours: 24),
  Duration(days: 7),
];

String _durationLabel(Duration duration) => switch (duration.inHours) {
  1 => '1 hour',
  24 => '24 hours',
  168 => '7 days',
  final hours => '$hours hours',
};

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.source, required this.onOpen});
  final _AddedSource source;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final preview = source.mediaPaths
        .where((path) => !_isVideoPath(path))
        .firstOrNull;
    final remotePreview = source.mediaUrls.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (preview != null)
              Image.file(File(preview), fit: BoxFit.cover, cacheWidth: 720)
            else if (remotePreview != null)
              Image.network(
                remotePreview.toString(),
                fit: BoxFit.cover,
                cacheWidth: 720,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(source.type.icon, size: 64),
                ),
              )
            else
              ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(source.type.icon, size: 64),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xdd000000)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${source.itemCount} items • ${source.mergedSourceCount} source${source.mergedSourceCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolCollectionCard extends StatelessWidget {
  const _PoolCollectionCard({
    required this.name,
    required this.icon,
    required this.items,
    required this.onOpen,
  });
  final String name;
  final IconData icon;
  final List<_MediaItem> items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.tertiaryContainer,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(icon, size: 48),
              const Spacer(),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('${items.length} items • pool collection'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CollectionPage extends StatefulWidget {
  const _CollectionPage({
    required this.name,
    required this.items,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });
  final String name;
  final List<_MediaItem> items;
  final Set<String> favoriteIds;
  final ValueChanged<_MediaItem> onToggleFavorite;

  @override
  State<_CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<_CollectionPage> {
  void _toggleFavorite(_MediaItem item) {
    widget.onToggleFavorite(item);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: widget.items.isEmpty
        ? const Center(
            child: Text('This collection does not contain any media yet.'),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(28),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 240,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _MediaCard(
                item: item,
                isFavorite: widget.favoriteIds.contains(item.id),
                onFavorite: () => _toggleFavorite(item),
                onOpen: () => _showMediaViewer(
                  context,
                  item,
                  widget.favoriteIds.contains(item.id),
                  _toggleFavorite,
                ),
              );
            },
          ),
  );
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.isFavorite,
    required this.onFavorite,
    required this.onOpen,
  });
  final _MediaItem item;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MediaVisual(item: item, fit: BoxFit.cover),
          Positioned(
            top: 10,
            right: 10,
            child: _GlassIconButton(
              tooltip: isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? Colors.redAccent : Colors.white,
              onPressed: onFavorite,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xcc000000)],
                ),
              ),
              child: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MediaVisual extends StatelessWidget {
  const _MediaVisual({required this.item, required this.fit});
  final _MediaItem item;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return const ColoredBox(
        color: Color(0xff26302a),
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white,
          size: 64,
        ),
      );
    }
    if (item.localPath != null) {
      return Image.file(File(item.localPath!), fit: fit, cacheWidth: 1600);
    }
    return Image.network(
      item.remoteUri.toString(),
      fit: fit,
      cacheWidth: 1600,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xffd9d2c5),
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .28),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .35)),
    ),
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    ),
  );
}

Future<void> _showMediaViewer(
  BuildContext context,
  _MediaItem item,
  bool initiallyFavorite,
  ValueChanged<_MediaItem> onToggleFavorite,
) => showDialog<void>(
  context: context,
  builder: (context) {
    var isFavorite = initiallyFavorite;
    return StatefulBuilder(
      builder: (context, setState) => Dialog.fullscreen(
        backgroundColor: const Color(0xff111311),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Center(
                  child: _MediaVisual(item: item, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: _GlassIconButton(
                tooltip: 'Close',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 20,
              right: 76,
              child: _GlassIconButton(
                tooltip: 'Image information',
                icon: Icons.info_outline_rounded,
                onPressed: () => _showMetadata(context, item),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: _GlassIconButton(
                tooltip: isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.redAccent : Colors.white,
                onPressed: () {
                  onToggleFavorite(item);
                  setState(() => isFavorite = !isFavorite);
                },
              ),
            ),
          ],
        ),
      ),
    );
  },
);

Future<void> _showMetadata(BuildContext context, _MediaItem item) async {
  final size = item.localPath == null
      ? null
      : await File(item.localPath!).length();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _MetadataRow(label: 'Source', value: item.sourceName),
          _MetadataRow(label: 'Type', value: item.isVideo ? 'Video' : 'Image'),
          if (size != null)
            _MetadataRow(label: 'File size', value: _formatBytes(size)),
          _MetadataRow(
            label: item.localPath == null ? 'Address' : 'Path',
            value: item.id,
          ),
        ],
      ),
    ),
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

enum _SourceAction { refresh, refreshRate, rename, editAddress, merge, remove }

class _SourcesPage extends StatelessWidget {
  const _SourcesPage({
    required this.sources,
    required this.onAddSource,
    required this.onUpdateSource,
    required this.onRemoveSource,
    required this.onMergeSource,
  });
  final List<_AddedSource> sources;
  final ValueChanged<_AddedSource> onAddSource;
  final _UpdateSource onUpdateSource;
  final ValueChanged<_AddedSource> onRemoveSource;
  final _MergeSource onMergeSource;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sources',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showAddSourceDialog(context, onAddSource),
              icon: const Icon(Icons.add),
              label: const Text('Add source'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (sources.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No sources yet. Add a feed, Google Photos selection, or local album.',
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final source = sources[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(child: Icon(source.type.icon)),
                    title: Text(source.name),
                    subtitle: Text(
                      source.endpoint?.toString() ??
                          (source.directoryPath == null
                              ? source.type.description
                              : '${source.directoryPath} • ${source.itemCount} items'),
                    ),
                    trailing: PopupMenuButton<_SourceAction>(
                      tooltip: 'Source actions',
                      onSelected: (action) =>
                          _handleAction(context, source, action),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _SourceAction.refresh,
                          enabled: source.type == _SourceType.rss,
                          child: const ListTile(
                            leading: Icon(Icons.refresh_rounded),
                            title: Text('Refresh'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _SourceAction.refreshRate,
                          enabled: source.type == _SourceType.rss,
                          child: ListTile(
                            leading: const Icon(Icons.schedule_rounded),
                            title: const Text('Refresh rate'),
                            subtitle: Text(
                              _durationLabel(source.refreshInterval),
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _SourceAction.rename,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Rename'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _SourceAction.editAddress,
                          child: ListTile(
                            leading: Icon(Icons.link_rounded),
                            title: Text('Edit address'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _SourceAction.merge,
                          enabled: sources.length > 1,
                          child: const ListTile(
                            leading: Icon(Icons.merge_rounded),
                            title: Text('Merge into…'),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: _SourceAction.remove,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Remove'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );

  Future<void> _handleAction(
    BuildContext context,
    _AddedSource source,
    _SourceAction action,
  ) async {
    switch (action) {
      case _SourceAction.refresh:
        final endpoint = source.endpoint;
        if (endpoint == null) return;
        try {
          final mediaUrls = await _fetchFeedMedia(endpoint);
          onUpdateSource(source, source.copyWith(mediaUrls: mediaUrls));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found ${mediaUrls.length} feed items.')),
          );
        } on Object catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not refresh feed: $error')),
          );
        }
      case _SourceAction.refreshRate:
        final interval = await showDialog<Duration>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Refresh feed every'),
            children: [
              for (final value in _refreshIntervals)
                ListTile(
                  leading: Icon(
                    value == source.refreshInterval
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  title: Text(_durationLabel(value)),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        );
        if (interval != null) {
          onUpdateSource(source, source.copyWith(refreshInterval: interval));
        }
      case _SourceAction.rename:
        final name = await _showValueDialog(
          context,
          title: 'Rename source',
          label: 'Source name',
          initialValue: source.name,
          validator: (value) => value.trim().isEmpty ? 'Enter a name.' : null,
        );
        if (name != null) onUpdateSource(source, source.copyWith(name: name));
      case _SourceAction.editAddress:
        await _editAddress(context, source);
      case _SourceAction.merge:
        final candidates = sources.where((item) => item != source).toList();
        final target = await showDialog<_AddedSource>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text('Merge ${source.name} into'),
            children: [
              for (final candidate in candidates)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, candidate),
                  child: ListTile(
                    leading: Icon(candidate.type.icon),
                    title: Text(candidate.name),
                    subtitle: Text('${candidate.itemCount} items'),
                  ),
                ),
            ],
          ),
        );
        if (target != null) onMergeSource(source, target);
      case _SourceAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove source?'),
            content: Text(
              '${source.name} and its collection will be removed. Local files will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) onRemoveSource(source);
    }
  }

  Future<void> _editAddress(BuildContext context, _AddedSource source) async {
    if (source.type == _SourceType.localAlbum) {
      final path = await getDirectoryPath(
        initialDirectory: source.directoryPath,
        confirmButtonText: 'Use folder',
      );
      if (path == null) return;
      try {
        final media = await _scanMediaDirectory(path);
        onUpdateSource(
          source,
          source.copyWith(directoryPath: path, mediaPaths: media),
        );
      } on FileSystemException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read that folder: ${error.message}'),
          ),
        );
      }
      return;
    }
    if (source.type == _SourceType.googlePhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnect Google Photos is not available yet.'),
        ),
      );
      return;
    }
    final address = await _showValueDialog(
      context,
      title: 'Edit source address',
      label: 'HTTPS feed URL',
      initialValue: source.endpoint?.toString() ?? '',
      validator: (value) => _validateFeedUrl(value),
    );
    if (address != null) {
      final endpoint = Uri.parse(address);
      if (source.type == _SourceType.rss) {
        try {
          final mediaUrls = await _fetchFeedMedia(endpoint);
          onUpdateSource(
            source,
            source.copyWith(endpoint: endpoint, mediaUrls: mediaUrls),
          );
        } on Object catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load feed: $error')),
          );
        }
      } else {
        onUpdateSource(source, source.copyWith(endpoint: endpoint));
      }
    }
  }
}

Future<String?> _showValueDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  required String? Function(String value) validator,
}) async {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          validator: (value) => validator(value?.trim() ?? ''),
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
