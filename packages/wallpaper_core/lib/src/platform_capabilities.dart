import 'media.dart';

enum WallpaperPlatform { macos, windows, ios, android }

enum WallpaperTarget { desktop, homeScreen, lockScreen }

final class PlatformCapabilities {
  const PlatformCapabilities({
    required this.platform,
    required this.targets,
    required this.mediaTypes,
    required this.unattendedChanges,
    required this.multiDisplay,
    this.explanation,
  });

  final WallpaperPlatform platform;
  final Set<WallpaperTarget> targets;
  final Set<MediaType> mediaTypes;
  final bool unattendedChanges;
  final bool multiDisplay;
  final String? explanation;

  bool supports(MediaType media, WallpaperTarget target) =>
      mediaTypes.contains(media) && targets.contains(target);

  static const macos = PlatformCapabilities(
    platform: WallpaperPlatform.macos,
    targets: {WallpaperTarget.desktop, WallpaperTarget.lockScreen},
    mediaTypes: {MediaType.image, MediaType.video},
    unattendedChanges: true,
    multiDisplay: true,
  );

  static const windows = PlatformCapabilities(
    platform: WallpaperPlatform.windows,
    targets: {WallpaperTarget.desktop},
    mediaTypes: {MediaType.image, MediaType.video},
    unattendedChanges: true,
    multiDisplay: true,
  );

  static const ios = PlatformCapabilities(
    platform: WallpaperPlatform.ios,
    targets: {WallpaperTarget.homeScreen, WallpaperTarget.lockScreen},
    mediaTypes: {MediaType.image},
    unattendedChanges: false,
    multiDisplay: false,
    explanation:
        'Wallpaper changes require a user-triggered Shortcuts handoff.',
  );

  static const android = PlatformCapabilities(
    platform: WallpaperPlatform.android,
    targets: {WallpaperTarget.homeScreen, WallpaperTarget.lockScreen},
    mediaTypes: {MediaType.image, MediaType.video},
    unattendedChanges: true,
    multiDisplay: false,
  );
}
